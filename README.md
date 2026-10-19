# GOV.UK Mobile UI Tests

Automated end-to-end tests for the GOV.UK mobile app using [Maestro](https://maestro.mobile.dev/), targeting both iOS and Android from a single test suite. Includes API-level schema validation via a Maven/Java module.

## Project Structure

```
├── flows/                          Maestro test flows
│   ├── onboarding-select-topics.yaml   Top-level test (has launchApp:)
│   ├── onboarding-skip-topics.yaml
│   ├── returning-user-can-edit-topics.yaml
│   ├── returning-user-selected-topics-and-analytics-pref-persisted.yaml
│   ├── auth/                       Sign-in flow
│   ├── onboarding/                 Onboarding steps (accept terms, etc.)
│   ├── topics/                     Topic selection/validation steps
│   ├── settings/                   Settings validation steps
│   ├── device-specific/            Platform-specific implementations
│   │   ├── Android/
│   │   └── iOS/
│   └── e2e/                        End-to-end flows combining API + UI
│
├── api-tests/                      Maven/Java API tests (schema validation)
│   └── src/
│       ├── main/java/              API client and models
│       └── test/java/              JUnit 5 test classes
│
├── .github/workflows/              CI pipelines (smoke + regression)
├── config.yaml                     Maestro workspace config
├── run-e2e.sh                      Full e2e pipeline script (API + UI)
└── .env example                    Environment variable template
```

## Prerequisites

- Java JDK 17+ ([Homebrew](https://formulae.brew.sh/formula/openjdk) or [ASDF](https://asdf-vm.com/))
- [Maestro CLI](https://maestro.mobile.dev/getting-started/installing-maestro)
- [Maven](https://maven.apache.org/) (for API tests only)
- A running iOS simulator or Android emulator with the GOV.UK app installed

### iOS Setup

```shell
# Build the app for the iOS simulator
xcrun xcodebuild -scheme 'GovUK' \
  -project 'GovUK.xcodeproj' \
  -configuration Debug \
  -sdk 'iphonesimulator' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath \
  build

# Start an iOS simulator via Maestro
maestro start-device --platform ios
```

### Android Setup

```shell
# Build the debug APK
./gradlew assembleDebug

# Start an Android emulator via Maestro and install the app
maestro start-device --platform android
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Environment Variables

Copy the template and fill in your credentials:

```shell
cp ".env example" .env
```

Maestro auto-loads `.env` from the working directory. Do **not** commit `.env` — it is in `.gitignore`.

| Variable | Description |
|----------|-------------|
| `APP_ID` | App bundle ID (default: `uk.gov.govuk.dev`, also set in `config.yaml`) |
| `GOVUK_EMAIL` | Test account email for the sign-in flow |
| `GOVUK_PASSWORD` | Test account password |
| `BASE_URL` | Backend API base URL (for API tests, default: `https://mobile.api.gov.uk`) |

## Running Tests

### Maestro UI Tests

```shell
# Run all tests (uses config.yaml for flow discovery)
maestro test

# Run tests filtered by tag
maestro test --include-tags=end-to-end

# Run a specific test flow
maestro test flows/onboarding-select-topics.yaml

# Pass credentials inline instead of using .env
maestro test --env GOVUK_EMAIL=you@example.com --env GOVUK_PASSWORD=secret

# Continuous mode — re-runs on file changes (useful during development)
maestro test -c flows/onboarding-select-topics.yaml
```

### API Tests

```shell
cd api-tests
mvn test
```

### Full End-to-End Pipeline (API + UI)

The `run-e2e.sh` script validates topics against the API schema, then runs the Maestro UI flow to verify the app matches:

```shell
./run-e2e.sh
```

This runs in two steps:
1. **API schema validation** — Maven tests fetch topics from the backend and export the expected list
2. **Maestro UI verification** — a Maestro flow asserts the app displays the same topics

## Tagging Convention

| Tag | Purpose |
|-----|---------|
| `end-to-end` | Multi-step user journeys |
| `e2e` | Cross-layer tests (API + UI) |

## CI Pipelines

| Workflow | Trigger | What it runs |
|----------|---------|--------------|
| **Smoke Tests** | Push/PR to `main` | Tagged `smoke` flows (currently being set up) |
| **Regression Tests** | Daily at 06:00 UTC + manual | Tagged `regression` flows on both iOS and Android |

## Conventions

- **App ID:** Always use `appId: ${APP_ID}` — the value is set centrally in `config.yaml`'s `env` block, not in individual flow files.
- **Platform handling:** Small differences use inline `when: platform:` conditionals. Larger divergences get separate files under `flows/device-specific/Android/` and `flows/device-specific/iOS/`.

## Useful Maestro Commands

```shell
maestro studio          # GUI to inspect the app's element hierarchy
maestro hierarchy       # JSON dump of the app element tree
maestro test -c file    # Continuous mode — re-runs on file save
```
