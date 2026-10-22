# GOV.UK Mobile UI Tests

Automated end-to-end tests for the GOV.UK mobile app using [Maestro](https://maestro.mobile.dev/), targeting both iOS and Android from a single test suite. Includes API-level schema validation via a Maven/Java module.

## Project Structure

```
├── flows/                          Maestro test flows
│   ├── onboarding-select-topics.yaml   Top-level test (has launchApp:)
│   ├── onboarding-skip-topics.yaml
│   ├── returning-user-can-edit-topics.yaml
│   ├── returning-user-selected-topics-and-analytics-pref-persisted.yaml
│   ├── auth/                       Sign-in flow (email, password + 2FA)
│   ├── onboarding/                 Onboarding steps (accept terms, etc.)
│   ├── topics/                     Topic selection/validation steps
│   ├── settings/                   Settings validation steps
│   ├── device-specific/            Platform-specific implementations
│   │   ├── Android/
│   │   └── iOS/
│   └── e2e/                        End-to-end flows combining API + UI
│
├── scripts/                        Helper scripts for test automation
│   └── generate-totp.js            TOTP code generator (unused — see run-tests.sh)
│
├── api-tests/                      Maven/Java API tests (schema validation)
│   └── src/
│       ├── main/java/              API client and models
│       └── test/java/              JUnit 5 test classes
│
├── .github/workflows/              CI pipelines (smoke + regression)
├── config.yaml                     Maestro workspace config
├── run-tests.sh                    Test runner (loads .env + generates TOTP code)
├── run-e2e.sh                      Full e2e pipeline script (API + UI)
└── .env.example                    Environment variable template
```

## Prerequisites

- Python 3 (for TOTP code generation — pre-installed on macOS)
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

## Environment Setup

### 1. Create a GOV.UK One Login test account

Create a test account on the GOV.UK staging environment:

1. Install the dev build of the app (`uk.gov.govuk.dev`) on your emulator/simulator
2. Launch the app and go through the sign-in flow
3. Choose **"Create a GOV.UK One Login"**
4. Enter your test email address and a password
5. When asked to set up 2FA, choose **"Authenticator app"**
6. On the QR code screen, tap **"I cannot scan the QR code"** to reveal the secret key
7. Copy the secret key (remove any spaces) — you'll need this for your `.env` file
8. You now need a 6-digit code to complete the setup. Generate one by running:
   ```shell
   ./scripts/generate-totp-code.sh YOUR_SECRET_KEY
   ```
   Replace `YOUR_SECRET_KEY` with the secret from step 7 (no spaces). The code refreshes every 30 seconds, so enter it promptly.

### 2. Configure environment variables

```shell
cp .env.example .env
```

Edit `.env` with your test account credentials:

```
GOVUK_EMAIL=your-email@example.com
GOVUK_PASSWORD=your-password
GOVUK_TOTP_SECRET=YOURSECRETKEYHERE
```

Do **not** commit `.env` — it is in `.gitignore`.

| Variable | Description |
|----------|-------------|
| `GOVUK_EMAIL` | Test account email for the sign-in flow |
| `GOVUK_PASSWORD` | Test account password |
| `GOVUK_TOTP_SECRET` | TOTP secret key from authenticator app setup (spaces removed) |
| `BASE_URL` | Backend API base URL (for API tests, default: `https://mobile.api.gov.uk`) |

### How 2FA automation works

The GOV.UK app requires two-factor authentication via an authenticator app on every sign-in. Instead of using a phone or authenticator app, the `run-tests.sh` wrapper script generates a fresh 6-digit TOTP code from the secret key using Python before each test run. This code is passed to Maestro as an environment variable (`GOVUK_TOTP_CODE`) and entered automatically during the sign-in flow.

This uses the same TOTP algorithm (RFC 6238) as any authenticator app — no external services or paid tools required.

## Running Tests

Always use the wrapper script to run tests — it loads `.env` and generates the TOTP code:

```shell
# Run a specific test flow
./run-tests.sh flows/onboarding-select-topics.yaml (example test)

# Run all tests
./run-tests.sh flows/

# Run tests filtered by tag
./run-tests.sh --include-tags=end-to-end /flows

# Continuous mode — re-runs on file changes (useful during development)
./run-tests.sh -c flows/onboarding-select-topics.yaml
```

> **Note:** Running `maestro test` directly will not work because Maestro does not auto-load `.env` files. The wrapper script is required to inject credentials and the TOTP code.

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

- **App ID:** `uk.gov.govuk.dev` is hardcoded in each flow file's `appId` field so flows are self-contained.
- **Platform handling:** Small differences use inline `when: platform:` conditionals. Larger divergences get separate files under `flows/device-specific/Android/` and `flows/device-specific/iOS/`.

## Useful Maestro Commands

```shell
maestro studio          # GUI to inspect the app's element hierarchy
maestro hierarchy       # JSON dump of the app element tree
maestro test -c file    # Continuous mode — re-runs on file save
```
