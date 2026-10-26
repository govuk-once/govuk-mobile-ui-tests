---
name: api-to-ui-test
description: Automate a GOV.UK app API end to end in this repo - REST Assured contract tests in api-tests/ plus a Maestro flow in flows/e2e/ that fetches the same API and checks the app shows that data. Use when asked to test, automate or add coverage for an API, endpoint or backend data the GOV.UK app displays, or to check that what the API returns appears in the app.
---

# API to UI test

Adds coverage for one API endpoint in two layers, following the pattern already used for topics:

| Layer | Tool | Lives in | Checks |
|---|---|---|---|
| API contract | Java 17, Maven, JUnit 5, REST Assured | `api-tests/` | Status, JSON, schema, expected content, invariants. No device. |
| API to UI | Maestro (YAML + JS) | `flows/e2e/`, `scripts/` | Fetch the same API inside the flow, then check each item is shown in the app |

Working example to copy: `api-tests/src/test/java/uk/gov/govuk/api/TopicsApiTest.java`, `flows/e2e/topics-match-api.yaml`, `scripts/fetch-topics.js`, `scripts/next-topic.js`.

## Ground rules

- **Never commit or push.** Leave changes in the working tree and list them. The user commits themselves.
- **Never delete files** without asking, except files this skill just created.
- **Secrets stay in `.env`** and reach Maestro through `-e` (see `run-tests.sh`). Never put credentials in YAML, JS or Java.
- **No hardcoded expected lists in the Maestro flow.** The flow must use what the API returns at run time.
- **The API tests and the flow must hit the same environment the app build uses** (step 1). Otherwise the test compares two different backends.

## Step 1: find the endpoint the app really calls

Do not guess or trust old test URLs (the original tests called `mobile.api.gov.uk/topics`, which does not respond).

1. **Path**: search the app source for the request.
   - iOS: `~/Documents/govuk-mobile-ios-app/Production/govuk_ios/Networking/GOVRequest/GOVRequest+*.swift` (for example `urlPath: "/static/topics/list"`).
   - Android: `~/Documents/govuk-mobile-android-app` (search for the path or the screen's repository class).
2. **Base URL**: read it from the installed dev build, not from source:
   ```shell
   plutil -p ~/Documents/govuk-mobile-ios-app/build/Build/Products/Debug-iphonesimulator/govuk_ios.app/Info.plist | grep -i url
   ```
   `BaseURL` is the app API (currently `https://app.integration.publishing.service.gov.uk`). Check which client the request uses (`appAPIClient` uses `BaseURL`, `govukAPIClient` uses `Constants.API.govukBaseUrl`).
3. **Probe it**:
   ```shell
   curl -s -w "\nHTTP %{http_code}\n" "<base><path>" | head -c 1500
   ```
   Note the shape (array or object), the field names, and whether it needs auth. If it needs a token or signing, stop and ask the user how test credentials should be supplied.
4. **Find the screen**: which screen shows this data, how to reach it after sign-in, and what text identifies each item (usually a `title` field). If unsure, open the screen on the simulator and run `maestro --device <id> hierarchy` to see the accessibility text Maestro matches on.

## Step 2: API contract tests (REST Assured)

`BaseApiTest` already sets up REST Assured (`api` request spec, `BASE_URL` env override, logging on failure). Add to it rather than duplicating setup.

1. Add a path constant to `BaseApiTest` (for example `static final String NEWS_PATH = "/static/news/list";`). If the endpoint is on a different base URL, add a second spec there with its own env override.
2. Add a JSON schema: `api-tests/src/test/resources/schema/<name>-schema.json`, draft-04 (REST Assured's validator), with `required` fields taken from the real response in step 1.
3. Add a model in `api-tests/src/main/java/uk/gov/govuk/api/model/` with `@JsonIgnoreProperties(ignoreUnknown = true)`, only if a test maps the response to objects.
4. Add `api-tests/src/test/java/uk/gov/govuk/api/<Name>ApiTest.java`, `@Tag("contract")`, extending `BaseApiTest`. Cover at least:
   - status 200 and JSON content type
   - matches the schema (`matchesJsonSchemaInClasspath("schema/<name>-schema.json")`)
   - business content the app relies on (required items present, non-empty titles)
   - invariants (no duplicate ids/refs, sensible counts)

   Template:
   ```java
   @Tag("contract")
   class NewsApiTest extends BaseApiTest {

       @Test
       void news_returns200WithJson() {
           given().spec(api)
           .when()
               .get(NEWS_PATH)
           .then()
               .statusCode(200)
               .contentType(ContentType.JSON);
       }

       @Test
       void news_matchesJsonSchema() {
           given().spec(api)
           .when()
               .get(NEWS_PATH)
           .then()
               .statusCode(200)
               .body(matchesJsonSchemaInClasspath("schema/news-schema.json"));
       }
   }
   ```
5. Run and fix until green:
   ```shell
   cd api-tests && mvn -q test
   # one class: mvn -q test -Dtest=NewsApiTest
   ```
   Reports: `api-tests/target/surefire-reports/`.

## Step 3: Maestro API-to-UI flow

### 3a. Fetch script: `scripts/fetch-<name>.js`

Copy `scripts/fetch-topics.js` and change the path and the field that identifies each item. It must:
- default the base URL to the app's `BaseURL` and allow `-e API_BASE_URL=...` (treat the string `'undefined'` as unset)
- `http.get(url)`, throw a clear error if status is not 200 or the list is empty
- store `output.<name>Titles`, `output.<name>Count`, `output.<name>Index = 0`
- `console.log` the fetched list, so the run log shows what was checked

Maestro's JS has `http` and `json()` but no npm modules or crypto. Use plain ES5-style JS.

### 3b. Loop script

Reuse `scripts/next-topic.js` if the output names match, or copy it to `scripts/next-<name>.js`. It sets `output.current...Pattern` with regex characters escaped, because Maestro text selectors are regular expressions.

### 3c. Flow: `flows/e2e/<name>-match-api.yaml`

Tag it `e2e` and keep it directly in `flows/e2e/` (run-e2e.sh runs that folder). Structure:

```yaml
appId: uk.gov.govuk.dev

tags:
  - e2e
---

- runScript:
    file: ../../scripts/fetch-news.js

- launchApp:
    clearState: true

- runFlow: ../auth/sign-in.yaml
- runFlow: ../onboarding/accept-terms.yaml
- runFlow: ../onboarding/accept-statistics-sharing.yaml
# ...reach the screen that shows this data (reuse subflows in flows/)

- repeat:
    while:
      true: ${output.newsIndex < output.newsCount}
    commands:
      - runScript:
          file: ../../scripts/next-news.js
      - scrollUntilVisible:
          element:
            text: ${output.currentNewsPattern}
          direction: DOWN
          timeout: 15000
          optional: true
      - runFlow:
          when:
            notVisible: ${output.currentNewsPattern}
          commands:
            - scrollUntilVisible:
                element:
                  text: ${output.currentNewsPattern}
                direction: UP
                timeout: 15000
                optional: true
      - assertVisible: ${output.currentNewsPattern}
```

Reuse existing subflows instead of re-writing sign-in or onboarding:
- `flows/auth/sign-in.yaml`: One Login sign-in, 2FA code via `scripts/generate-totp.js`, passkey skip
- `flows/auth/sign-in-if-needed.yaml`: after `stopApp`/`launchApp` (simulators have no Face ID, so the app signs out on restart)
- `flows/onboarding/*`, `flows/topics/*`, `flows/settings/*`, `flows/device-specific/*` (platform branches with `when: platform`)

### Maestro rules learned in this repo

- **Optional screens**: wait for this screen OR any later one with `extendedWaitUntil` and a `|` pattern, then act inside `runFlow: when: visible:`. Screens (terms, statistics, passkey, "Save Password?") appear or not depending on account and device.
- **Long form for options**: `tapOn: "X"` cannot take options. Use `tapOn:` with `text:` plus `waitToSettleTimeoutMs`, `retryTapIfNoChange` indented under it. `optional: true` goes inside the command, never beside it.
- **`centerElement: true` belongs to `scrollUntilVisible`**, not `tapOn`. Use it before tapping items in lists with a fixed bottom bar, or the tap can hit the bar.
- **Visible text is not always the accessibility text** (iOS "Edit" is "Edit your topics"). If a visible element is "not found", check `maestro hierarchy` or the app's `.xcstrings` files.
- **Switches**: assert with `text: "<label>"` plus `checked: true`, never by position or a "1" value.
- **Escape regex characters** in text selectors (`?` becomes `\\?` in YAML).

## Step 4: run and verify

Maestro needs Java on PATH. If `java` is missing in the shell:
```shell
export JAVA_HOME=/opt/homebrew/opt/openjdk@17 PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
```

1. **Syntax**: `ruby -ryaml -e 'YAML.load_stream(File.read(ARGV[0]))' <flow>`, `bash -n run-e2e.sh`.
2. **Fetch only** (no app): a scratch flow with just the `runScript` fetch plus the loop of `next-*.js`, run with `maestro --device <id> test <file>`. Confirm the log shows the fetched list and N iterations.
3. **Full pipeline** (keep the Mac awake):
   ```shell
   caffeinate -i ./run-e2e.sh
   ```
   `run-tests.sh` picks the iPhone 18 Pro simulator by default (`DEVICE_NAME` / `DEVICE_ID` in `.env`, or `--device`).
4. **Prove the checks ran**: in `~/.maestro/tests/<latest>/maestro.log`, count `Assert that "${output.current...Pattern}" is visible COMPLETED`. It must equal the number of items the API returned.
5. **On failure**: open the screenshot in `~/.maestro/tests/<latest>/<flow>/screenshots/` and fix the cause. Do not paper over a real mismatch between API and app; report it.
6. **Do not break the existing suite**: if shared subflows changed, also run `./run-tests.sh --include-tags=end-to-end flows/`.

## Step 5: report back

Tell the user:
- which endpoint and base URL were tested, and how they were confirmed (app source path and `Info.plist` value)
- the new and changed files, all uncommitted
- results: number of contract tests passed, number of items checked in the app, device used
- anything not covered (for example Android not run, endpoints needing auth)
