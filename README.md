# AttestService

App Attest service built with Swift and Vapor

The service stores issued challenges and attested keys in Postgres. Redis is not required

## Required environment variables
- TEAM_ID
- BUNDLE_ID
- BEARER_KEY (requires `Authorization: Bearer <key>` on protected routes)
- DATABASE_URL or the individual Postgres values below

## Optional environment variables
- DATABASE_HOST (default: localhost)
- DATABASE_PORT (default: 5432)
- DATABASE_USERNAME or DATABASE_USER (default: vapor)
- DATABASE_PASSWORD
- DATABASE_NAME (default: attest_service)
- APP_ATTEST_ENVIRONMENT
- CHALLENGE_TTL_SECONDS (default: 300)

Migrations always run automatically during service startup

## Routes

`POST /challenge`

Creates a single-use challenge

```json
{
  "userID": "optional-user-id",
  "purpose": "attestation"
}
```

`purpose` can be `attestation` or `assertion`. The default is `attestation`

`POST /attest`

Consumes an attestation challenge, validates the App Attest object, stores the public key and receipt, and returns the registered key

```json
{
  "challenge": "base64",
  "attestation": "base64",
  "keyID": "base64"
}
```

`POST /assert`

Consumes an assertion challenge, validates the assertion with the stored public key, and advances the replay counter

```json
{
  "challenge": "base64",
  "assertion": "base64",
  "keyID": "base64",
  "clientData": "base64-json"
}
```

The decoded `clientData` must be JSON signed by the App Attest assertion:

```json
{
  "challenge": "base64",
  "action": "login",
  "payloadHash": "base64-sha256"
}
```

The attester validates the assertion and returns the signed `action` and `payloadHash`. The billing backend must compare those values with the operation and SHA-256 digest of the request body it received

## Billing backend integration

The billing backend should treat attestation as key enrollment and assertion as the normal request proof

- Request `/challenge` with `purpose: "attestation"` when the app has no attested key yet, after reinstall, after restore, or after `DCError.invalidKey`
- Request `/challenge` with `purpose: "assertion"` for normal login/signup or other protected requests when the app already has a key
- Forward the user identifier, when known, as `userID` so new keys can be associated with the account
- Post typed JSON to `/attest` and `/assert`; avoid converting an arbitrary JSON object with `toString()` as the service contract
- For `/assert`, compare the returned `action` and `payloadHash` with the backend route and request payload before accepting the request
- Do not reject a new key for an existing user by default. Reinstall and device restore rotate App Attest keys, so multiple active keys per user are expected
- Keep hCaptcha or another fallback/risk path for unsupported platforms and failed App Attest attempts

## Getting Started

**Local Postgres**
```bash
cp .env.example .env
docker compose up -d db
```

**Run with Docker Compose**
```bash
docker compose up --build app
```

**Build**
```bash
swift build
```

**Run**
```bash
swift run
```

**Execute tests**
```bash
swift test
```
