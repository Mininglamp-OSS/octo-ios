# iOS Firebase Configuration Template

This fork ships **no** `GoogleService-Info.plist`. The `octo-release`
pipeline deny-paths `**/GoogleService-Info.plist` before publishing so no
internal Firebase project ID leaks out. You must supply your own if your
fork uses Firebase (Analytics, Crashlytics, Messaging, Remote Config).

## What you need

1. A Firebase project on [console.firebase.google.com](https://console.firebase.google.com)
2. An iOS app registered in that project under your own Bundle ID (the one
   you configured per [`README-BUNDLE-ID.md`](README-BUNDLE-ID.md) — not
   the `com.example.octo` placeholder)
3. The `GoogleService-Info.plist` downloaded from Project Settings → General
   → Your apps → Download `GoogleService-Info.plist`

## Where to put it

Drop the file at the project location Firebase expects:

```
DMWork/GoogleService-Info.plist
```

Make sure the file is added to the DMWork target in Xcode (File inspector →
Target Membership). Do **not** add the real file to the `octo-ios` fork's
history — add it to your downstream private build repo or supply it at CI
time from a secret store.

## Multi-environment setup (dev / staging / prod)

A common pattern is one Firebase project per environment. Keep three
variants of the file:

```
Config/Firebase-Dev/GoogleService-Info.plist
Config/Firebase-Staging/GoogleService-Info.plist
Config/Firebase-Prod/GoogleService-Info.plist
```

…and copy the correct one into place via a build phase script:

```bash
# Build Phases → New Run Script Phase (before "Copy Bundle Resources")
set -e
ENV_DIR="${SRCROOT}/Config/Firebase-${CONFIGURATION}"
if [ -f "${ENV_DIR}/GoogleService-Info.plist" ]; then
  cp "${ENV_DIR}/GoogleService-Info.plist" "${SRCROOT}/DMWork/"
else
  echo "warning: no Firebase config for ${CONFIGURATION}"
fi
```

## Firebase features that also leave files

If you enable any of the features below, confirm that the deny-paths in
`configs/octo-ios.yaml` are **NOT** hiding something your fork actually
needs. The default deny-path list only removes:

- `**/GoogleService-Info.plist`
- `**/firebase/**` (the Firebase CLI cache directory)
- `**/fastlane/match/**` (signing assets, not Firebase)

Crashlytics symbol uploads, App Distribution, Remote Config defaults, and
Messaging server keys all live in Firebase project settings — they do not
produce tracked files in the repo, so they are not affected by the scrub.

## Troubleshooting

- **App crashes on launch with `FIR_EXCEPTION`** → confirm the Bundle ID
  in `GoogleService-Info.plist` matches `PRODUCT_BUNDLE_IDENTIFIER` in the
  pbxproj. Xcode `Show in Finder` → Quick Look the plist to compare.
- **Crashlytics uploads fail in CI** → Firebase upload step expects the
  plist at build time; mount the secret-store value into
  `${BUILT_PRODUCTS_DIR}/GoogleService-Info.plist` before running.
