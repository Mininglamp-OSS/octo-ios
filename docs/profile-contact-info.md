# Profile contact information (iOS)

This records the intended behavior of the PR #108 revision, following the
product owner's direction to retain the user-detail card layout and hide
cooling-off accounts' contacts from peers. It is not a claim that issue #103
has already been updated or approved by its reviewer.

Tracking: [requirement #103](https://github.com/Mininglamp-OSS/octo-ios/issues/103),
[user detail #108](https://github.com/Mininglamp-OSS/octo-ios/pull/108),
[personal information #107](https://github.com/Mininglamp-OSS/octo-ios/pull/107).

## Placement is defined by the screen

- The personal information screen (`WKMeInfoVC`, PR #107) places phone and email
  after the name and before the short number.
- The user-detail screen (`WKUserInfoVC`, PR #108) keeps the avatar, name and
  short number in its existing table header. A separate contact section follows
  the header and precedes the remark section. This layout also applies when
  opening one's own user-detail screen from a member list.
- Phone precedes email. The contact section has a 10pt gap above it. When it is
  visible, the remark section also has a 10pt gap above it; when absent, the
  remark section retains its existing 0pt gap.
- Only internal contact rows have separators, inset 17pt on both sides. A
  one-row contact card has no separator at its bottom edge.

The unconditional placement sentence currently in #103 must be amended to
this screen-specific rule by the requirement owner. Code comments alone do
not resolve that discrepancy.

## Visibility and data contract

Server authorization is a necessary condition for disclosure. The iOS
presentation layer additionally applies the deployment flag, robot exclusion
and the following explicit account-state rule. It never reconstructs fields
withheld by the server.

| Account state (`is_destroy`) | Peer viewing | Self viewing |
| --- | --- | --- |
| 0: normal | Eligible for the card | Eligible for the card |
| 1: cooling-off, recoverable | Entire contact card hidden | Eligible for the card |
| 2: deletion completed | Entire contact card hidden | No supported signed-in flow; the self branch still requires server fields |

"Eligible" is not an unconditional disclosure: the total switch must be on,
the account must not be a robot, and fields must actually be returned.
Preserve `is_destroy` as an integer throughout parsing and rendering; never
collapse cooling-off and completed deletion into a boolean.

| API contact value | UI |
| --- | --- |
| Key absent, JSON null, or non-string | Omit that row |
| Empty string | Show the specified unfilled-information text, without reveal/copy |
| Nonempty phone | Peer: initially "Tap to view", with no number or copy menu; self: full number with country code |
| Nonempty email | Show full value subject to single-line visual truncation; copy retains the full string |
| Both rows omitted | Omit the entire contact section and its extra remark gap |

Peer phone reveal displays/copies the number without a country code. Self
formatting prefers `phone_country_code`, falling back to `zone`; both `+86`
and `0086` normalize to one `+86` prefix. Phone/email remain in VM memory and
are not written to `channelInfo.extra`.

Reveal state belongs to each page's context, not the global endpoint closure.
Leaving the page clears it even when that same controller remains on the
navigation stack. Returning from a chat must not restore the revealed value.
Self display remains complete, including during cooling-off.

The cooling-off rule is an iOS display policy. If the product intends to prevent
API disclosure on every client, the backend contract needs a corresponding
change. This revision does not claim to change backend authorization.

## Regression verification

`WKUserInfoContactTests` is included in the `LiMaoBase_Tests` target. Its tests
exercise the real `UserModel` parser, global contact endpoint, per-page VM and
controller disappearance hook, with no live API or persisted contact records:

- Numeric/string states 0, 1 and 2 remain distinct; null state does not crash.
- Normal/cooling-off/deleted peers, cooling-off self, flag off and robot cases.
- Missing, null, non-string, empty and populated contact fields.
- Reveal, conceal on the same VM, controller disappearance and two live cards.
- Preferred country code, legacy `+`/`00` formats and invalid country fields.
- Single/two-row separators and conditional remark spacing.
- Early appmodule callbacks, duplicate config callbacks and failed-config callbacks
  that must not trigger a fresh request through the global config getter.

Manual visual acceptance: light/dark appearance; Chinese/English at 375pt;
one/two/no rows; a long email; empty placeholders; hidden/revealed phone;
self from both entry points; navigating to chat and returning. Screenshots
must show the header, contact section and remark section together.

Actual device results and screenshots: [PR #108 validation](qa/pr108/README.md).

## Review handoff

1. The requirement owner updates #103's placement and cooling-off policy and
   links the decision in #108. This remains necessary to close A1/A2.
2. Include the revised screenshots and actual test/build results; do not equate
   a successful compile with executed tests.
3. Resolve `check-sprint`: it currently reports no linked issue. Because #103
   also covers #107, prefer a scoped user-detail sub-issue and `Closes #<id>`
   in #108 rather than prematurely closing the parent requirement. Rerun the
   check and satisfy any further project/sprint requirements it reports.
4. If #107 lands first, rebase and keep one English definition per shared key.
5. Blacklist direction, copy-country-code changes and alternative placeholder
   wording are separate product decisions, not implicit changes in this patch.
