# Test Data

All runtime configuration is supplied via environment variables — no secrets or environment-specific values are hardcoded in YAML or Java files.

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `APP_ID` | Maestro | App bundle ID (default: `uk.gov.govuk.dev`) |
| `GOVUK_EMAIL` | Maestro | GOV.UK One Login test email |
| `GOVUK_PASSWORD` | Maestro | GOV.UK One Login test password |
| `BASE_URL` | Maven/Java | Backend API base URL |

## Setup

Copy `.env.example` at the project root to `.env` and fill in your values:

```bash
cp .env.example .env
```

Maestro picks up `.env` automatically when run from the project root. The Java API tests read variables from the shell environment (set them before running `mvn test`).
