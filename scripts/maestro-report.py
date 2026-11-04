#!/usr/bin/env python3
"""Builds test-output/report.html from Maestro's results.

Reads, from the folder given (test-output/ by default):
  report.xml, report-retry.xml     JUnit results of the run and the rerun
  debug/<test>/commands.json       every step with its status (and the same in debug-retry/)
  debug/<test>/screenshots/*.png   screenshots, named after the step they were taken at

Called by run-tests.sh after each run. Standard library only (Python 3.9+).
Typed text is never shown, so passwords and codes stay out of the report.
"""
import html
import json
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime

# Steps Maestro adds itself, which mean nothing to a reader
HIDDEN_COMMANDS = {"defineVariablesCommand", "applyConfigurationCommand"}

STATUS_LABELS = {
    "COMPLETED": ("pass", "✓", "Passed"),
    "FAILED": ("fail", "✗", "Failed"),
    "SKIPPED": ("skip", "–", "Skipped (condition not met)"),
    "WARNED": ("warn", "!", "Optional step not met"),
}


def esc(text):
    return html.escape(str(text), quote=True)


def selector_text(selector):
    if not selector:
        return ""
    for key in ("textRegex", "idRegex"):
        if selector.get(key):
            prefix = "id " if key == "idRegex" else ""
            return f'{prefix}"{selector[key]}"'
    return "element"


def condition_text(condition):
    if not condition:
        return ""
    if condition.get("visible"):
        return f"{selector_text(condition['visible'])} is visible"
    if condition.get("notVisible"):
        return f"{selector_text(condition['notVisible'])} is not visible"
    if condition.get("platform"):
        return f"platform is {condition['platform']}"
    if condition.get("scriptCondition"):
        return condition["scriptCondition"]
    return "condition"


def describe(name, cmd):
    """A plain-English line for one step."""
    if name == "tapOnElement":
        return f"Tap {selector_text(cmd.get('selector'))}"
    if name == "inputTextCommand":
        return "Enter text (value hidden)"
    if name == "assertConditionCommand":
        what = condition_text(cmd.get("condition"))
        if cmd.get("timeout"):
            return f"Wait up to {int(cmd['timeout']) // 1000}s until {what}"
        return f"Check {what}"
    if name == "scrollUntilVisible":
        return f"Scroll {cmd.get('direction', '').lower()} to {selector_text(cmd.get('selector'))}"
    if name == "runFlowCommand":
        text = f"Run {cmd['sourceDescription']}" if cmd.get("sourceDescription") else "Run steps"
        if cmd.get("condition"):
            text += f" (when {condition_text(cmd['condition'])})"
        return text
    if name == "runScriptCommand":
        return f"Run script {cmd.get('sourceDescription', '')}".strip()
    if name == "evalScriptCommand":
        return "Run JavaScript"
    if name == "launchAppCommand":
        return "Launch the app" + (" with cleared data" if cmd.get("clearState") else "")
    if name == "stopAppCommand":
        return "Stop the app"
    if name == "repeatCommand":
        parts = []
        if cmd.get("condition"):
            parts.append(f"while {condition_text(cmd['condition'])}")
        if cmd.get("times"):
            parts.append(f"up to {cmd['times']} times")
        return "Repeat " + ", ".join(parts) if parts else "Repeat"
    if name == "waitForAnimationToEndCommand":
        return "Wait for animations to finish"
    if name == "backPressCommand":
        return "Press back"
    if name == "hideKeyboardCommand":
        return "Hide the keyboard"
    if name == "takeScreenshotCommand":
        return "Take a screenshot"
    # Anything else: "swipeCommand" -> "Swipe"
    words = name.replace("Command", "")
    return "".join(" " + c.lower() if c.isupper() else c for c in words).strip().capitalize()


def read_junit(path):
    """Returns (suite attributes, {test name: testcase info})."""
    if not os.path.isfile(path):
        return {}, {}
    root = ET.parse(path).getroot()
    suite = root.find("testsuite")
    tests = {}
    for case in root.iter("testcase"):
        failure = case.find("failure")
        tests[case.get("name")] = {
            "name": case.get("name"),
            "file": case.get("file", ""),
            "time": float(case.get("time", 0) or 0),
            "status": case.get("status", "SUCCESS" if failure is None else "ERROR"),
            "failure": failure.text if failure is not None else "",
        }
    return (suite.attrib if suite is not None else {}), tests


def read_steps(debug_dir, test_name):
    path = os.path.join(debug_dir, test_name, "commands.json")
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as f:
        entries = json.load(f)
    steps = []
    for entry in entries:
        name = next(iter(entry.get("command", {})), "")
        if name in HIDDEN_COMMANDS:
            continue
        meta = entry.get("metadata", {})
        evaluated = meta.get("evaluatedCommand", {}).get(name) or entry["command"][name]
        steps.append({
            "text": describe(name, evaluated),
            "status": meta.get("status", ""),
            "depth": meta.get("depth", 0),
            "seconds": (meta.get("duration") or 0) / 1000,
            "error": (meta.get("error") or {}).get("message", ""),
        })
    return steps


def screenshots(report_dir, debug_name, test_name):
    folder = os.path.join(report_dir, debug_name, test_name, "screenshots")
    if not os.path.isdir(folder):
        return []
    return [f"{debug_name}/{test_name}/screenshots/{n}" for n in sorted(os.listdir(folder)) if n.endswith(".png")]


def format_time(seconds):
    if seconds >= 60:
        return f"{int(seconds // 60)}m {int(seconds % 60)}s"
    return f"{seconds:.1f}s" if seconds < 10 else f"{int(seconds)}s"


def render_run(report_dir, debug_name, test, title):
    passed = test["status"] == "SUCCESS"
    steps = read_steps(os.path.join(report_dir, debug_name), test["name"])
    shots = screenshots(report_dir, debug_name, test["name"])
    out = [f'<h3>{esc(title)}: <span class="{"pass" if passed else "fail"}">'
           f'{"Passed" if passed else "Failed"}</span> in {format_time(test["time"])}</h3>']
    if not passed:
        failed_steps = [s for s in steps if s["status"] == "FAILED"]
        failed_step = failed_steps[-1]["text"] if failed_steps else "unknown step"
        out.append(f'<div class="failure"><strong>Failed at:</strong> {esc(failed_step)}<br>'
                   f'<strong>Reason:</strong> {esc(test["failure"] or "not given")}</div>')
        if shots:
            out.append(f'<p><a href="{esc(shots[-1])}"><img class="shot" src="{esc(shots[-1])}" '
                       f'alt="Screen when the test failed"></a><br><span class="muted">Screen when it failed: '
                       f'{esc(os.path.basename(shots[-1]))}</span></p>')
    if steps:
        counts = {}
        for s in steps:
            counts[s["status"]] = counts.get(s["status"], 0) + 1
        short = {"COMPLETED": "passed", "FAILED": "failed", "SKIPPED": "skipped", "WARNED": "optional, not needed"}
        summary = ", ".join(f"{n} {short.get(k, k.lower())}" for k, n in counts.items())
        noun = "step" if len(steps) == 1 else "steps"
        out.append(f'<details{"" if passed else " open"}><summary>All {len(steps)} {noun} ({esc(summary)})</summary>')
        out.append('<table class="steps"><thead><tr><th></th><th>Step</th><th>Time</th></tr></thead><tbody>')
        for s in steps:
            css, icon, label = STATUS_LABELS.get(s["status"], ("", "?", s["status"]))
            error = f'<div class="err">{esc(s["error"])}</div>' if s["error"] and s["status"] == "FAILED" else ""
            out.append(f'<tr class="{css}"><td title="{esc(label)}">{icon}</td>'
                       f'<td style="padding-left:{8 + 18 * s["depth"]}px">{esc(s["text"])}{error}</td>'
                       f'<td class="num">{format_time(s["seconds"])}</td></tr>')
        out.append("</tbody></table></details>")
    elif not passed:
        out.append('<p class="muted">No step log was saved for this test.</p>')
    if shots and passed:
        links = ", ".join(f'<a href="{esc(p)}">{esc(os.path.basename(p))}</a>' for p in shots)
        out.append(f'<p class="muted">Screenshots: {links}</p>')
    return "\n".join(out)


def build(report_dir):
    suite, first = read_junit(os.path.join(report_dir, "report.xml"))
    _, retry = read_junit(os.path.join(report_dir, "report-retry.xml"))
    if not first:
        return None

    rows, sections = [], []
    passed = flaky = failed = 0
    for name, test in first.items():
        rerun = retry.get(name)
        if test["status"] == "SUCCESS":
            result, css = "Passed", "pass"
            passed += 1
        elif rerun and rerun["status"] == "SUCCESS":
            result, css = "Flaky: failed, then passed on rerun", "warn"
            flaky += 1
        else:
            result, css = "Failed" + (" twice" if rerun else ""), "fail"
            failed += 1
        total_time = test["time"] + (rerun["time"] if rerun else 0)
        rows.append(f'<tr><td><a href="#{esc(name)}">{esc(name)}</a><div class="muted">{esc(test["file"])}</div></td>'
                    f'<td class="{css}">{esc(result)}</td><td class="num">{format_time(total_time)}</td></tr>')
        parts = [f'<section id="{esc(name)}"><h2>{esc(name)}</h2><p class="muted">{esc(test["file"])}</p>',
                 render_run(report_dir, "debug", test, "First run")]
        if rerun:
            parts.append(render_run(report_dir, "debug-retry", rerun, "Rerun"))
        parts.append("</section>")
        sections.append("\n".join(parts))

    overall = "fail" if failed else ("warn" if flaky else "pass")
    if failed:
        overall_text = f"{failed} failed, {flaky} flaky, {passed} passed, out of {len(first)}"
    elif flaky:
        overall_text = f"Passed with {flaky} flaky: {passed} passed first time, out of {len(first)}"
    else:
        overall_text = f"All {passed} passed"
    device = suite.get("device", "")
    started = suite.get("timestamp", "")
    try:
        started = datetime.fromisoformat(started).strftime("%d %b %Y, %H:%M")
    except ValueError:
        pass

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Maestro test report</title>
<style>
body{{font-family:-apple-system,"Segoe UI",Arial,sans-serif;max-width:1000px;margin:24px auto;padding:0 16px;color:#1d2731;background:#fff;line-height:1.45}}
h1{{margin:0 0 4px}} h2{{margin:32px 0 2px;padding-top:16px;border-top:1px solid #d5dbe0}} h3{{font-size:16px;margin:16px 0 8px}}
table{{border-collapse:collapse;width:100%;margin:8px 0}} th,td{{text-align:left;padding:6px 8px;border-bottom:1px solid #e3e7ea;vertical-align:top}}
th{{font-size:12px;text-transform:uppercase;color:#5b6670;letter-spacing:.04em}} .num{{text-align:right;white-space:nowrap;color:#5b6670}}
.pass{{color:#0b6b3a}} .fail{{color:#b3261e}} .warn{{color:#8a5a00}} .skip{{color:#8a949c}} .muted{{color:#6b757d;font-size:13px}}
tr.fail td{{background:#fdecea}} tr.skip td{{color:#8a949c}} tr.warn td{{color:#8a5a00}}
.banner{{padding:12px 16px;border-radius:8px;font-weight:600;margin:12px 0}} .banner.pass{{background:#e6f4ec}} .banner.fail{{background:#fdecea}} .banner.warn{{background:#fff4dc}}
.failure{{background:#fdecea;border-left:4px solid #b3261e;padding:10px 12px;margin:8px 0}} .err{{font-size:13px;color:#b3261e;margin-top:2px}}
.shot{{max-width:320px;border:1px solid #d5dbe0;border-radius:8px}} details summary{{cursor:pointer;color:#1d5f8a;margin:8px 0}}
</style></head><body>
<h1>Maestro test report</h1>
<p class="muted">{esc(started)} · {esc(device)}</p>
<div class="banner {overall}">{esc(overall_text)}</div>
<table><thead><tr><th>Test</th><th>Result</th><th>Time</th></tr></thead><tbody>
{"".join(rows)}
</tbody></table>
{"".join(sections)}
</body></html>
"""


def main():
    report_dir = sys.argv[1] if len(sys.argv) > 1 else "test-output"
    page = build(report_dir)
    if page is None:
        print(f"No report.xml in {report_dir}, so no HTML report was made", file=sys.stderr)
        return 1
    with open(os.path.join(report_dir, "report.html"), "w", encoding="utf-8") as f:
        f.write(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())