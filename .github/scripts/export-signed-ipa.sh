#!/bin/bash
# Export a signed IPA when every required Apple signing secret is present.
# If any required secret is missing, this exits successfully so the unsigned
# IPA path can keep CI green. See PROGRESS.md for the secret names.

set -euo pipefail

cd "${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"

required_secrets=(
  APPLE_CERTIFICATE_P12_BASE64
  APPLE_CERTIFICATE_PASSWORD
  APPLE_PROVISIONING_PROFILE_BASE64
  APPLE_TEAM_ID
)
missing=()
for name in "${required_secrets[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Signed IPA skipped. Missing repository secrets: ${missing[*]}"
  echo "The unsigned IPA is still uploaded. See PROGRESS.md for how to add these secrets."
  echo "enabled=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

echo "enabled=true" >> "${GITHUB_OUTPUT:-/dev/null}"

EXPORT_METHOD="${APPLE_EXPORT_METHOD:-ad-hoc}"
case "$EXPORT_METHOD" in
  ad-hoc|development|app-store|app-store-connect|enterprise) ;;
  *)
    echo "APPLE_EXPORT_METHOD must be ad-hoc, development, app-store, app-store-connect, or enterprise (got: ${EXPORT_METHOD})."
    exit 1
    ;;
esac

if [[ ! "$APPLE_TEAM_ID" =~ ^[A-Za-z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must be the 10-character Apple Developer Team ID."
  exit 1
fi

BUNDLE_ID=$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*//p' Config/PocketRepublic.xcconfig)
BUNDLE_ID=$(printf '%s' "$BUNDLE_ID" | tr -d '[:space:]')
if [[ "$BUNDLE_ID" != "com.jscreate.pocketrepublic" ]]; then
  echo "Expected bundle ID com.jscreate.pocketrepublic in Config/PocketRepublic.xcconfig, found '${BUNDLE_ID}'."
  exit 1
fi
export BUNDLE_ID EXPORT_METHOD

WORK_DIR="${RUNNER_TEMP:-/tmp}/pocketrepublic-signing"
mkdir -p "$WORK_DIR"
CERT_PATH="$WORK_DIR/certificate.p12"
PROFILE_PATH="$WORK_DIR/profile.mobileprovision"
EXPORT_PLIST="$WORK_DIR/ExportOptions.plist"
ARCHIVE_PATH="$WORK_DIR/PocketRepublic.xcarchive"
EXPORT_DIR="$WORK_DIR/export"
KEYCHAIN_PATH="$WORK_DIR/signing.keychain-db"
KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

cleanup() {
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  rm -f "$CERT_PATH" "$PROFILE_PATH"
}
trap cleanup EXIT

python3 - "$CERT_PATH" "$PROFILE_PATH" <<'PY'
import base64, os, pathlib, sys
def decode(name):
    return base64.b64decode("".join(os.environ[name].split()))
cert_path, profile_path = sys.argv[1], sys.argv[2]
pathlib.Path(cert_path).write_bytes(decode("APPLE_CERTIFICATE_P12_BASE64"))
pathlib.Path(profile_path).write_bytes(decode("APPLE_PROVISIONING_PROFILE_BASE64"))
PY

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"

if [[ "$EXPORT_METHOD" == "development" ]]; then
  identity_pattern='Development|Developer'
else
  identity_pattern='Distribution'
fi

identities=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | sed -n 's/.*"\(.*\)"/\1/p' || true)
CODE_SIGN_IDENTITY=
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if printf '%s\n' "$line" | grep -Eq "$identity_pattern"; then
    CODE_SIGN_IDENTITY=$line
    break
  fi
done <<EOF
$identities
EOF
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  echo "No code signing identity matching /${identity_pattern}/."
  echo "Ad hoc, App Store, and enterprise exports need an Apple Distribution certificate. Development exports need Apple Development."
  echo "Installed identities:"
  printf '%s\n' "$identities"
  exit 1
fi
echo "Using signing identity: $CODE_SIGN_IDENTITY"

eval "$(python3 - "$PROFILE_PATH" <<'PY'
import os, plistlib, subprocess, sys
profile = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", sys.argv[1]]))
name = profile.get("Name") or ""
uuid = profile.get("UUID") or ""
entitlements = profile.get("Entitlements", {})
app_id = entitlements.get("application-identifier") or entitlements.get("com.apple.application-identifier") or ""
teams = profile.get("TeamIdentifier") or []
if not name or not uuid or not app_id:
    raise SystemExit("Provisioning profile is missing Name, UUID, or application-identifier.")
bundle_id = os.environ["BUNDLE_ID"]
team_id = os.environ["APPLE_TEAM_ID"]
prefix, _, suffix = app_id.partition(".")
if prefix != team_id:
    raise SystemExit(f"Provisioning profile team {prefix} does not match APPLE_TEAM_ID {team_id}.")
if teams and team_id not in teams:
    raise SystemExit(f"Provisioning profile TeamIdentifier {teams} does not include {team_id}.")
wildcard = suffix == "*" or (suffix.endswith(".*") and bundle_id.startswith(suffix[:-1]))
if suffix != bundle_id and not wildcard:
    raise SystemExit(
        f"Provisioning profile App ID {app_id} does not match {team_id}.{bundle_id}. "
        "Create the profile for com.jscreate.pocketrepublic."
    )
# Shell-safe assignments for the caller.
def sh(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"
print(f"PROFILE_NAME={sh(name)}")
print(f"PROFILE_UUID={sh(uuid)}")
print(f"PROFILE_APP_ID={sh(app_id)}")
PY
)"

export CODE_SIGN_IDENTITY PROFILE_NAME
echo "Using provisioning profile: $PROFILE_NAME ($PROFILE_UUID) App ID $PROFILE_APP_ID"
profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_dir"
cp "$PROFILE_PATH" "$profile_dir/$PROFILE_UUID.mobileprovision"

python3 - "$EXPORT_PLIST" <<'PY'
import os, plistlib, sys
plist = {
    "method": os.environ["EXPORT_METHOD"],
    "teamID": os.environ["APPLE_TEAM_ID"],
    "signingStyle": "manual",
    "signingCertificate": os.environ["CODE_SIGN_IDENTITY"],
    "provisioningProfiles": {
        os.environ["BUNDLE_ID"]: os.environ["PROFILE_NAME"],
    },
    "destination": "export",
    "manageAppVersionAndBuildNumber": False,
}
with open(sys.argv[1], "wb") as handle:
    plistlib.dump(plist, handle)
PY

auth_args=()
asc_ready=0
if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
  asc_ready=1
  key_dir="$WORK_DIR/private_keys"
  mkdir -p "$key_dir"
  python3 - "$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8" <<'PY'
import base64, os, pathlib, sys
data = base64.b64decode("".join(os.environ["APP_STORE_CONNECT_API_KEY_BASE64"].split()))
if b"PRIVATE KEY" not in data:
    raise SystemExit("APP_STORE_CONNECT_API_KEY_BASE64 is not an App Store Connect .p8 private key.")
pathlib.Path(sys.argv[1]).write_bytes(data)
PY
  auth_args=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
  echo "App Store Connect API key is available for export."
elif [[ -n "${APP_STORE_CONNECT_KEY_ID:-}${APP_STORE_CONNECT_ISSUER_ID:-}${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
  echo "App Store Connect API key is incomplete. Export continues with the certificate and provisioning profile only."
  echo "Set all of APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_BASE64."
fi

archive_cmd=(
  xcodebuild
  -project PocketRepublic.xcodeproj
  -scheme PocketRepublic
  -configuration Release
  -sdk iphoneos
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  -derivedDataPath "$WORK_DIR/DerivedData"
)
export_cmd=(
  xcodebuild
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_DIR"
  -exportOptionsPlist "$EXPORT_PLIST"
)
if [[ ${#auth_args[@]} -gt 0 ]]; then
  archive_cmd+=("${auth_args[@]}")
  export_cmd+=("${auth_args[@]}")
fi
archive_cmd+=(
  CODE_SIGN_STYLE=Manual
  CODE_SIGNING_ALLOWED=YES
  CODE_SIGNING_REQUIRED=YES
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME"
  archive
)
"${archive_cmd[@]}"
"${export_cmd[@]}"

ipa=
while IFS= read -r candidate; do
  [[ -z "$candidate" ]] && continue
  ipa=$candidate
  break
done <<EOF
$(find "$EXPORT_DIR" -name '*.ipa')
EOF
if [[ -z "${ipa}" ]]; then
  echo "xcodebuild -exportArchive did not write an .ipa"
  ls -la "$EXPORT_DIR" || true
  exit 1
fi

cp "$ipa" "$PWD/PocketRepublic-signed.ipa"
(
  cd "$PWD"
  shasum -a 256 PocketRepublic-signed.ipa > PocketRepublic-signed.ipa.sha256
)

check_dir=$(mktemp -d)
unzip -q -d "$check_dir" PocketRepublic-signed.ipa
signed_bundle=$(plutil -extract CFBundleIdentifier raw -o - "$check_dir/Payload/PocketRepublic.app/Info.plist")
if [[ "$signed_bundle" != "$BUNDLE_ID" ]]; then
  echo "Signed IPA bundle ID is ${signed_bundle}, expected ${BUNDLE_ID}."
  exit 1
fi
if [[ ! -f "$check_dir/Payload/PocketRepublic.app/embedded.mobileprovision" ]]; then
  echo "Signed IPA is missing embedded.mobileprovision."
  exit 1
fi
rm -rf "$check_dir"

echo "Signed IPA ready (${EXPORT_METHOD}), bundle ID ${signed_bundle}."
if [[ "$asc_ready" -eq 1 && "$EXPORT_METHOD" != "app-store" && "$EXPORT_METHOD" != "app-store-connect" ]]; then
  echo "The App Store Connect API key was used for export authentication. This workflow does not upload the IPA."
fi
