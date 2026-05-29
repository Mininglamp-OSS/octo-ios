# iOS Universal Links Configuration

The OCTO iOS client's `*.entitlements` files declare a placeholder
Universal Link host: **`applinks:example.com`**. This is intentional — the
upstream fork is not bound to any specific web domain. You must change
this to your own domain and host a matching `apple-app-site-association`
file before Universal Links will work.

## What got rewritten

The `octo-release` pipeline rewrote these internal hosts to
`applinks:example.com`:

- `applinks:xming.ai`
- `applinks:im-test.xming.ai`
- `applinks:im.deepminer.com.cn`
- `applinks:im-test.deepminer.com.cn`
- `applinks:deepminer.com.cn`

If you find any `applinks:*.deepminer.com.cn` / `applinks:*.xming.ai` /
`applinks:*.dmwork.*` / `applinks:*.mininglamp.*` entry in your fork, file
an issue — the rewrite map missed it.

## Files to update

Search every `.entitlements` file for the `com.apple.developer.associated-
domains` array and replace `applinks:example.com` with your own:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:your-domain.com</string>
    <string>applinks:*.your-domain.com</string>
</array>
```

Typical locations:

- `DMWork/DMWork.entitlements`
- `DMWork-ShareExtension/DMWork-ShareExtension.entitlements`
- `DMWork-NotificationService/DMWork-NotificationService.entitlements`

Extensions that need to handle deep links must carry the same
`associated-domains` entitlement.

## Hosting `apple-app-site-association`

Apple requires a JSON file at
`https://your-domain.com/.well-known/apple-app-site-association` served
as `Content-Type: application/json` over HTTPS, reachable **without**
redirects. A minimal file:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": ["ABCDE12345.com.yourcompany.octo"],
        "paths": [ "/chat/*", "/space/*", "/invite/*" ]
      }
    ]
  }
}
```

- `ABCDE12345` is your Team ID (Apple Developer portal → Membership).
- `com.yourcompany.octo` is the Bundle ID you configured in
  [`README-BUNDLE-ID.md`](README-BUNDLE-ID.md).
- `paths` are the URL paths your app should intercept.

## Validating

After deploying the association file and signing a build with the new
entitlements:

```bash
# From macOS with Xcode installed:
xcrun swcutil download -d your-domain.com
xcrun swcutil verify -d your-domain.com -u https://your-domain.com/some-path
```

Or let Apple's public CDN validator check for you:
`https://branch.io/resources/aasa-validator/` (third-party, but quick).

## Troubleshooting

- **Universal Link opens Safari instead of the app** → 9 times out of 10
  the `apple-app-site-association` file is served with wrong MIME type or
  is behind a redirect. Run `curl -sI https://your-domain.com/.well-known/
  apple-app-site-association` and verify `Content-Type: application/json`,
  `HTTP/2 200`, no `Location:` header.
- **First install works, re-install does not** → iOS caches
  association data. Remove the app, reboot, reinstall.
- **Extension targets do not intercept links** → each extension needs its
  own `applinks:` entitlement entry and code that calls
  `UIApplication.shared.open(url)`.
