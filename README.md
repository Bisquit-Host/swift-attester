# AttestService

AppAttest service built with Swift & Vapor. Currently replaced with [rust-attester](https://github.com/Bisquit-Host/rust-attester) in order to lower the resource usage

## Required environment props
- TEAM_ID
- BUNDLE_ID
- CHALLENGE_SECRET
- BEARER_KEY (requires `Authorization: Bearer <key>` on protected routes)

## Getting Started

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
