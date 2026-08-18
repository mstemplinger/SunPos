#!/bin/bash
#
# Archiviert SunPos, exportiert eine signierte IPA und lädt sie nach App Store Connect.
#
# Voraussetzungen, die nur über App Store Connect zu erledigen sind:
#   1. Bundle-ID im Developer-Portal registriert (Certificates, Identifiers & Profiles)
#   2. App-Datensatz in App Store Connect angelegt (gleiche Bundle-ID)
# Schlüssel-ID und Issuer-ID stehen in AppStore/asc-config.local.sh – die Datei ist
# absichtlich nicht eingecheckt, weil dieses Repository öffentlich ist. Vorlage:
# asc-config.local.sh.example. Der Schlüssel selbst liegt unter
# ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 und gehört nirgends ins Repo.
#
# Aufruf:  ./AppStore/submit.sh
#
set -euo pipefail

CONFIG="$(dirname "$0")/asc-config.local.sh"
[[ -f "$CONFIG" ]] && source "$CONFIG"

KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
TEAM_ID="NY363CML59"

if [[ -z "$KEY_ID" || -z "$ASC_ISSUER_ID" ]]; then
  echo "ASC_KEY_ID und ASC_ISSUER_ID fehlen." >&2
  echo "Lege AppStore/asc-config.local.sh nach dem Muster von" >&2
  echo "asc-config.local.sh.example an oder setze beide als Umgebungsvariablen." >&2
  exit 1
fi
ARCHIVE="build/SunPos.xcarchive"
EXPORT_DIR="build/export"

cd "$(dirname "$0")/.."
rm -rf "$ARCHIVE" "$EXPORT_DIR"

echo "→ Archivieren"
xcodebuild -project SunPos.xcodeproj -scheme SunPos -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "→ Exportieren"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

IPA=$(find "$EXPORT_DIR" -name '*.ipa' | head -1)
echo "→ Prüfen: $IPA"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "→ Hochladen"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "Fertig. Der Build erscheint nach der Verarbeitung in App Store Connect unter TestFlight."
