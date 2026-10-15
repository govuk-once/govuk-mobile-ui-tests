# GOV.UK Mobile UI Tests

Automated end-to-end tests for the GOV.UK mobile app using [Maestro](https://maestro.mobile.dev/), targeting both iOS and Android from a single test suite.

## Project Structure

```
├── tests/              Orchestrator flows (what Maestro discovers and runs)
│   ├── onboarding/     Onboarding journey tests
│   ├── topics/         Topic selection/editing tests
│   └── settings/       Settings persistence tests
│
├── subflows/           Reusable steps (called via runFlow:, never run directly)
│   ├── onboarding/     Sign-in, accept terms, etc.
│   ├── topics/         Select, validate, edit topics
│   ├── settings/       Validate settings state
│   └── navigation/     Cross-feature platform utilities (back, toggle checks)
│
├── platform/           Platform-specific implementations
│   ├── android/        Android-only flows (organised by feature)
│   └── ios/            iOS-only flows (organised by feature)
│
├── .github/workflows/  CI pipelines (smoke + regression)
├── config.yaml         Maestro workspace config
└── .env.example        Environment variable template
```

**Rule of thumb:** If a flow has `launchApp:`, it goes in `tests/`. Otherwise it goes in `subflows/` or `platform/`.

## Prerequisites

- Java JDK ([homebrew](https://formulae.brew.sh/formula/openjdk) or [asdf](https://asdf-vm.com/))
- [Maestro CLI](https://maestro.mobile.dev/getting-started/installing-maestro)
- A running simulator/emulator with the GOV.UK app installed

### iOS Setup

```shell
xcrun xcodebuild -scheme 'GovUK' \
  -project 'GovUK.xcodeproj' \
  -configuration Debug \
  -sdk 'iphonesimulator' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath \
  build

maestro start-device --platform ios
```

### Android Setup

```shell
./gradlew assembleDebug
maestro start-device --platform android
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Environment Variables

Copy `.env.example` and fill in your credentials:

```shell
cp .env.example .env
```

Required variables:

| Variable | Description |
|----------|-------------|
| `GOVUK_EMAIL` | Test account email for sign-in |
| `GOVUK_PASSWORD` | Test account password |
| `APP_ID` | App bundle ID (default: `uk.gov.govuk.dev`, set in config.yaml) |

## Running Tests

```shell
# Run all tests (uses config.yaml for flow discovery)
maestro test

# Run by tag
maestro test --include-tags=smoke
maestro test --include-tags=regression
maestro test --include-tags=onboarding

# Run a specific test directly
maestro test tests/onboarding/onboarding-select-topics.yaml

# Pass credentials inline (alternative to .env)
maestro test --env GOVUK_EMAIL=you@example.com --env GOVUK_PASSWORD=secret
```

## Tagging Convention

| Tag | Purpose |
|-----|---------|
| `smoke` | Critical path, fast — runs on every push/PR |
| `regression` | Full coverage — runs nightly |
| `end-to-end` | Multi-step user journeys |
| `onboarding`, `topics`, `settings` | Feature area |
| `p0`, `p1` | Priority (`p0` = must-not-break) |

## Conventions

- **Naming:** directories are lowercase singular nouns. Test files: `{feature}-{scenario}.yaml`. Sub-flow files: `{verb}-{subject}.yaml`.
- **Platform handling:** Small differences use inline `when: platform:` conditionals in sub-flows. Larger divergences get separate files under `platform/android/` and `platform/ios/`.
- **App ID:** Always use `appId: ${APP_ID}` — the value is set in `config.yaml`'s `env` block.
- **Tags:** Only orchestrator test files in `tests/` carry tags. Sub-flows do not need tags.

## Useful Maestro Commands

```shell
maestro studio          # GUI to visualise app structure
maestro hierarchy       # JSON listing of app element tree
maestro test -c file    # Continuous mode for interactive development
```
