# iOS Bundle ID Configuration

The OCTO iOS client ships with **`com.example.octo`** as a placeholder Bundle
Identifier. This is intentional — the upstream OSS fork is not provisioned for
any specific Apple Developer team, and you cannot build, sign, or distribute
this repository as-is.

Before building your fork, replace the placeholder in every location below
with your own reverse-DNS identifier (e.g. `com.yourcompany.octo`).

## Files to change

| File | What to change |
|------|----------------|
| `DMWork.xcodeproj/project.pbxproj` | Every `PRODUCT_BUNDLE_IDENTIFIER = com.example.octo…;` line |
| `DMWork/*.entitlements` | `application-identifier`, any `com.example.octo…` values |
| `DMWork/Info.plist` | `CFBundleIdentifier` if present (usually `$(PRODUCT_BUNDLE_IDENTIFIER)`) |
| `GoogleService-Info.plist` | Regenerate from your Firebase console (see `firebase-template.md`) |
| Any `.mobileprovision` | Re-provision with your own Apple Developer account |
| Extension targets (Share / Notification / Watch / Widget) | Each has its own child `PRODUCT_BUNDLE_IDENTIFIER` — update every one |

## One-liner (macOS / BSD `sed`)

```bash
# Replace throughout the project (dry-run with -n + p first!)
grep -rl 'com.example.octo' . \
    | xargs sed -i '' 's|com\.example\.octo|com.yourcompany.octo|g'
```

On GNU sed (Linux), drop the empty `-i ''` argument:

```bash
grep -rl 'com.example.octo' . \
    | xargs sed -i 's|com\.example\.octo|com.yourcompany.octo|g'
```

## After renaming

1. Open `DMWork.xcworkspace` in Xcode.
2. Targets → Signing & Capabilities → sign into your Apple Developer account
   and let Xcode regenerate provisioning profiles.
3. Verify every extension target signs against the same team.
4. Re-run `pod install` if the Podfile's `target 'DMWork' do` block was
   renamed.

## Universal links

If your app ships with Universal Links, also see
[`universal-link-setup.md`](universal-link-setup.md) — the `applinks:*`
entries in `*.entitlements` point at `example.com` as a placeholder and
must be pointed at your own domain **and** hosted `apple-app-site-
association` file.

## Questions

This is not a one-time checklist — every time you pull upstream you must
re-check these files in case the placeholder strings have moved. Consider
committing a local post-`git pull` hook that fails loudly if
`com.example.octo` reappears in the project.
