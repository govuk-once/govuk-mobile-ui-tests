---
name: maestro-ui-test
description: Write, fix or extend Maestro UI tests for the GOV.UK app in this repo - new user-journey tests in flows/, reusable subflows, iOS/Android differences, and diagnosing and fixing failing tests from Maestro screenshots and logs. Use when asked to add a UI or end-to-end test, automate a screen or user journey, fix a failing or flaky Maestro test, or make tests work on a new device or app version.
---

# Maestro UI test

Two modes, often both in one task:
- **New test**: automate a user journey (for example "a user can add their local council").
- **Fix**: make a failing or flaky test pass for the right reason.

For tests that compare API data with what the app shows, use the `api-to-ui-test` skill instead.

## Ground rules

- **Never commit or push.** Leave changes in the working tree and list them. The user commits themselves.
- **Never delete files** without asking, except files this skill just created. Ask before deleting logs, builds or simulators, even when the disk is full.
- **Secrets stay in `.env`** and reach Maestro through `-e` via `run-tests.sh`. Never put credentials in YAML or JS.
- **Fix the cause, not the symptom.** Do not add blind waits, `optional: true` on real checks, or weaker assertions to make a test pass. If the app is genuinely wrong, say so.
- **Change shared subflows carefully**: they are used by every test. After changing one, run the whole suite.

## How the framework is laid out

```
run-tests.sh            loads .env, picks the device (iPhone 18 Pro by default), runs Maestro with -e values
flows/*.yaml            tests: start the app, carry a tag (end-to-end)
flows/auth/             sign-in.yaml (One Login + 2FA), sign-in-if-needed.yaml (after a restart)
flows/onboarding/       terms, statistics, notifications (each optional)
flows/topics/           select, skip, validate topics
flows/settings/         settings checks
flows/device-specific/  iOS/ and Android/ steps, chosen with `when: platform`
flows/e2e/              API-to-UI tests (api-to-ui-test skill)
scripts/                JS for Maestro (generate-totp.js etc.)
```

A **test** is a top-level file in `flows/` that starts with `launchApp` and has a `tags:` header. A **subflow** has neither and is called with `runFlow`. `maestro test flows/` only picks up files directly in `flows/`, never subfolders.

## Mode A: write a new test

### 1. Understand the journey
Ask for or work out: the starting state (new user or returning), each screen and action, and the outcome to check. Turn it into a short numbered list before writing YAML.

### 2. Learn what Maestro can see on each screen
- Drive the simulator to the screen (a scratch flow that reuses the existing sign-in and onboarding subflows is quickest), then:
  ```shell
  maestro --device <id> hierarchy > /tmp/h.json
  ```
  Look at `accessibilityText`, `text`, `value`, `resource-id` and `checked` for the elements you need.
- Visible text is not always what Maestro matches. Check the app's strings and accessibility labels:
  - iOS: `~/Documents/govuk-mobile-ios-app/Production/govuk_ios/Resources/Strings/*.xcstrings`, views in `Production/govuk_ios/Views` and `SwiftUIViews`, shared components in `build/SourcePackages/checkouts/govuk-mobile-ios-gov-kit`
  - Android: `~/Documents/govuk-mobile-android-app`
- Prefer ids (`id: "toggle Benefits"` on Android) or accessibility labels over positions (`index:`) or values like `"1"`.

### 3. Reuse before writing
Start from existing subflows: `auth/sign-in.yaml`, `auth/sign-in-if-needed.yaml`, `onboarding/*`, `topics/*`, `settings/*`, `device-specific/*`. Only create a new subflow when a step will be used by more than one test, and put it in the matching folder.

### 4. Write the test
`flows/<journey-name>.yaml`:

```yaml
appId: uk.gov.govuk.dev

tags:
  - end-to-end
---

- launchApp:
    clearState: true

- runFlow: auth/sign-in.yaml
- runFlow: onboarding/accept-terms.yaml
- runFlow: onboarding/accept-statistics-sharing.yaml
- runFlow: topics/skip-initial-topics-selection.yaml
- runFlow: onboarding/skip-notifications.yaml

# ...the journey being tested
```

- **Returning-user journeys**: after `stopApp` and `launchApp`, add `- runFlow: auth/sign-in-if-needed.yaml`. Simulators have no Face ID, so the app signs the user out on restart.
- **Platform differences**: put them in `flows/device-specific/` with `runFlow: when: platform: iOS | Android`, so the test itself stays the same on both.
- **Tags**: `end-to-end` for the main suite. Add others (for example `smoke`) as a list in the header, never as `@tag` lines.

### 5. Run it (see "Run and verify")

## Mode B: fix a failing test

### 1. Reproduce on the same device
```shell
caffeinate -i ./run-tests.sh flows/<test>.yaml
```
Run with no extra flags first, the way the user does, so device and environment match.

### 2. Read the evidence
- The failing step: the `[Failed] <test> (<reason>)` line.
- The screenshot: `~/.maestro/tests/<latest>/<test>/screenshots/` (the last file is the failure). Always look at it; the reason text alone is often misleading.
- Step timings: `grep onCommand ~/.maestro/tests/<latest>/maestro.log`. Gaps of many minutes usually mean the Mac slept.

### 3. Match the cause

| Symptom on the screenshot or log | Usual cause | Fix |
|---|---|---|
| Element is on screen but "not found" | Accessibility text differs from visible text (iOS "Edit" is "Edit your topics") | Match the real label, for example `"Edit\|Edit your topics"`. Confirm with `hierarchy` or `.xcstrings` |
| A screen the test expected never appeared | Screen is conditional (terms, statistics, notifications, passkey, "Save Password?") | Optional-screen pattern below |
| Test checked a screen while a different one was still showing | Steps in the wrong order (for example topics checked before "Allow notifications?" was dismissed) | Reorder the subflows |
| Tap landed on the wrong thing / flow jumped ahead | Element under a fixed bar or at the screen edge | `scrollUntilVisible` with `centerElement: true` before the tap |
| Text typed into nothing, or "Enter the code" / password error | Field not ready when typed | Wait for the field (`extendedWaitUntil`), long-form `tapOn` with `waitToSettleTimeoutMs`, retry loop if needed |
| "The code you entered is not correct" | 2FA code made too early and expired | Code must be generated in the flow by `scripts/generate-totp.js`, never once in `run-tests.sh` |
| `undefined` typed into a field | Variable not passed with `-e`, or YAML and `run-tests.sh` use different variable names | Make `run-tests.sh` and the subflow agree |
| Welcome screen appears after restart | No Face ID on the simulator | `auth/sign-in-if-needed.yaml` after `launchApp` |
| Matched "the first 1 on screen" or `index: N` broke | Positional selector | Select by label plus state (`text: "<label>"`, `checked: true`) |
| "Invalid Command Format" | YAML shape | Long-form command with options indented under it; `optional` inside the command |
| "Package ... is not installed" / app will not launch | Wrong device chosen, or a broken install | Pass `--device` or check `DEVICE_NAME`; reinstall the build with `xcrun simctl install` |
| XCUITest driver status check keeps failing, long silent gap | Mac slept, or a hung driver | Run with `caffeinate -i`; stop leftover `xcodebuild test-without-building` processes |
| "Unable to locate a Java Runtime" | Java not on PATH | `export JAVA_HOME=/opt/homebrew/opt/openjdk@17 PATH="$JAVA_HOME/bin:$PATH"` (the user adds it to `~/.zshrc` themselves) |
| "No space left on device" | Disk full | Stop and tell the user. Do not delete anything without asking |

If the app itself has changed (a redesigned screen, new labels), confirm it in the iOS or Android source before rewriting steps, and say so in the report.

### 4. Retry once to tell flaky from broken
If the cause is unclear, rerun the single test. Passing on retry means timing; make the step wait for the right thing rather than leaving it flaky.

## Patterns to use

**Optional screen** (wait for it or any later screen, then act only if it is showing):
```yaml
- extendedWaitUntil:
    visible: "Terms and conditions|Share statistics|Select relevant topics|Allow notifications\\?|Your topics"
    timeout: 20000

- runFlow:
    when:
      visible: "Terms and conditions"
    commands:
      - tapOn: "Accept and continue"
```

**Long-form command** (short form `tapOn: "X"` cannot take options):
```yaml
- tapOn:
    text: "Not now"
    waitToSettleTimeoutMs: 10000
    retryTapIfNoChange: true
```

**Scroll and centre before tapping list items**:
```yaml
- scrollUntilVisible:
    element:
      text: "Money and tax.*"
    centerElement: true
- tapOn: "Money and tax.*"
```

**Retry while a page is still showing** (used for the 2FA code):
```yaml
- repeat:
    while:
      visible: "Enter the 6 digit security code shown in your authenticator app"
    times: 3
    commands:
      - tapOn: ...
      - extendedWaitUntil:
          notVisible: "Enter the 6 digit security code shown in your authenticator app"
          timeout: 15000
          optional: true
```

**Switch state**:
```yaml
- assertVisible:
    text: "Share app usage statistics"
    checked: true
```

**Rules of thumb**
- Text selectors are regular expressions: escape `?`, `.`, `(` etc. (`"Allow notifications\\?"`).
- `centerElement` belongs to `scrollUntilVisible`, not `tapOn`.
- `optional: true` goes inside a command, never beside it.
- Prefer `extendedWaitUntil` on the thing you need over fixed waits.
- `assertNotVisible` only checks the current screen; scroll before asserting something is absent from a long list.

## Run and verify

Maestro needs Java on PATH (see the table above).

```shell
# one test
caffeinate -i ./run-tests.sh flows/<test>.yaml

# the main suite
caffeinate -i ./run-tests.sh --include-tags=end-to-end flows/

# another device
./run-tests.sh --device <simulator-id or emulator-5554> flows/<test>.yaml
```

- `run-tests.sh` defaults to the **iPhone 18 Pro** simulator; set `DEVICE_NAME` or `DEVICE_ID` in `.env`, or pass `--device`.
- Before running: the GOV.UK dev app (`uk.gov.govuk.dev`) must be installed on that device, and `.env` must have `GOVUK_EMAIL`, `GOVUK_PASSWORD`, `GOVUK_TOTP_SECRET`.
- Validate YAML before running: `ruby -ryaml -e 'YAML.load_stream(File.read(ARGV[0]))' <file>`.
- A test only counts as fixed when it passes as part of the full suite, not just on its own. Run the suite after changing any shared subflow.
- Do not run two Maestro runs on the same device at once. Stop leftover runs first.

## Report back

Tell the user:
- for each failure: the step, what the screenshot showed, the cause, and the fix
- the new and changed files, all uncommitted
- results per test (passed/failed, time) and the device used
- anything not covered or still uncertain (for example Android not run, a step that passed only on retry, an app change that looks like a real bug)
