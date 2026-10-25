# Progress

## 2026-10-25 — Installable IPA CI and bundle identifier

Investigated the `xcode-27` runner label against the current `actions/runner-images` catalog and the latest successful run on `main` (`40201533131`).

- `xcode-27` is a real GitHub-hosted label (image `xcode-27-arm64`, macOS 27.0.1). It is still marked preview in the runner-images README, and it is the hosted image that installs Xcode 27.1 at `/Applications/Xcode_27.1.app` (build `27A9275`, the image default) with the iOS 27.1 SDK.
- `macos-latest` / `macos-26` are the GA macOS labels, and they stop at Xcode 26.6 (iOS 26.5 SDK). This app calls `GeometryProxy.reservedRegions` inside `if #available(iOS 27.1, *)`, which has to compile against the iOS 27.1 SDK. Moving the workflow to those labels would fail the device build.
- Scheme `PocketRepublic` and project `PocketRepublic.xcodeproj` already match the repo. The previous unsigned archive path is valid: the `main` artifact is a device IPA (`DTPlatformName` `iphoneos`, `DTSDKName` `iphoneos27.1`) with bundle ID `com.example.PocketRepublic` and no signature.
- The workflow still always builds with `CODE_SIGNING_ALLOWED=NO`, zips `Payload/PocketRepublic.app`, and uploads `PocketRepublic-unsigned-ipa`. That path does not read Apple secrets, so CI stays green without them.
- When the signing secrets below are all set, the same job archives with manual signing, writes export options from the single bundle ID, and uploads `PocketRepublic-signed-ipa`. Default export method is `ad-hoc` (installable on devices listed in the profile). No secrets are stored in the repo.

Replaced the placeholder bundle ID everywhere it was defined. `PRODUCT_BUNDLE_IDENTIFIER` lived only in the Debug and Release target settings in `PocketRepublic.xcodeproj/project.pbxproj` (`com.example.PocketRepublic`). There is no checked-in Info.plist (`GENERATE_INFOPLIST_FILE` writes `CFBundleIdentifier` from that setting) and there was no export-options file. Both configurations now include `Config/PocketRepublic.xcconfig`, which is the only definition:

`com.jscreate.pocketrepublic`

The unsigned packaging step fails the job if the built `Info.plist` does not match that ID.

### Secrets required for a signed IPA

Add these as repository Actions secrets (Settings → Secrets and variables → Actions). Do not commit the files.

| Secret | What to put in it |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64 of the Apple Distribution `.p12` (use Apple Development instead when `APPLE_EXPORT_METHOD` is `development`). `base64 -i Certificates.p12 \| tr -d '\n'` |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that `.p12`. |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 of the `.mobileprovision` whose App ID is `com.jscreate.pocketrepublic` (or a matching wildcard). Same `base64` command as the certificate. |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID. |

Optional App Store Connect API key. The export step passes it to `xcodebuild` when all three are set. This workflow does not upload the IPA.

| Secret | What to put in it |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | Key ID of the App Store Connect API key. |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations. |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64 of the downloaded `AuthKey_<KEY_ID>.p8`. |

Optional repository variable (not a secret): `APPLE_EXPORT_METHOD`. One of `ad-hoc` (default), `development`, `app-store`, `app-store-connect`, or `enterprise`.

### Apple account steps still required

1. Enroll the Apple Developer Program account that should own `com.jscreate.pocketrepublic`.
2. Register an explicit App ID for `com.jscreate.pocketrepublic` (no extra capabilities; the target has no entitlements file).
3. Create an Apple Distribution certificate (or Apple Development, for a development export), install it in Keychain Access, and export it as a password-protected `.p12`.
4. For an ad hoc IPA, register each test device UDID, then create an Ad Hoc provisioning profile for that App ID and those devices. Use an App Store profile only when `APPLE_EXPORT_METHOD` is `app-store` or `app-store-connect`.
5. Base64-encode the `.p12` and `.mobileprovision` and save the four required secrets above.
6. Download the unsigned artifact `PocketRepublic-unsigned-ipa` from the Actions run, unzip it, and use `PocketRepublic-unsigned.ipa` with a re-signing tool if you are not ready to add those secrets. iOS will not install that IPA until something signs it with a provisioning profile.
7. After the secrets are set, re-run the workflow and download `PocketRepublic-signed-ipa`. Install an ad hoc build in Finder or Apple Configurator on a registered device. Uploading to App Store Connect (Transporter or `altool`) is still a separate step; the API key only authenticates export.
