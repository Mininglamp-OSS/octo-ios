# iOS Code Signing Template

This fork intentionally ships **no signing material**. Every `*.p12`,
`*.cer`, `*.mobileprovision`, `*.p8`, and `*.certSigningRequest` has been
stripped before publish by the `octo-release` pipeline. You cannot build
for distribution without providing your own.

## What you need

| Asset | Where it comes from | Fork location |
|-------|--------------------|---------------|
| Apple Developer account | [developer.apple.com](https://developer.apple.com) | N/A (account-level) |
| Team ID | Apple Developer membership portal | Xcode → Signing & Capabilities → Team |
| `*.p12` (distribution cert) | Keychain Access → export from a signing cert you created | **Do NOT commit** — keep in CI secret store |
| `*.mobileprovision` | Apple Developer portal or `fastlane match` | **Do NOT commit** — regenerate per machine |
| APNs auth key `*.p8` | Apple Developer portal → Keys | **Do NOT commit** — keep in your backend's secret store |

## Recommended tooling

- **`fastlane match`** — stores certs + profiles in a private git repo,
  each developer runs `match development` / `match appstore` to sync. The
  `overlay` deny-list explicitly deny-paths `**/fastlane/match/**` so no
  internal match repo bleeds through to the OSS mirror.
- **Xcode Automatic Signing** — fine for hobby forks; fails for any app
  that ships extensions or Universal Links because provisioning profiles
  need App IDs in the developer portal.

## Before your first build

```bash
# 1. Log into Xcode as your developer account
open -a Xcode

# 2. Open the project
open DMWork.xcworkspace

# 3. For the DMWork target and every extension target:
#    Signing & Capabilities → check "Automatically manage signing"
#    Team → select your team
#    Bundle Identifier → change from com.example.octo (see README-BUNDLE-ID.md)
```

## CI signing (GitHub Actions)

Use a dedicated secret store (1Password, AWS Secrets Manager, GH Actions
secrets). Never commit signing material to your fork — even "encrypted
.p12 + hard-coded password" is not safe.

A minimal `fastlane` + GH Actions recipe lives in the upstream Fastlane
docs: <https://docs.fastlane.tools/actions/match/>.
