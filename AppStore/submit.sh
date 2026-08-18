#!/bin/bash
#
# Archiviert SunPos, exportiert eine signierte IPA und lädt sie nach App Store Connect.
#
# Voraussetzungen, die nur über App Store Connect zu erledigen sind:
#   1. Bundle-ID im Developer-Portal registriert (Certificates, Identifiers & Profiles)
#   2. App-Datensatz in App Store Connect angelegt (gleiche Bundle-ID)
#   3. Issuer-ID des API-Schlüssels: App Store Connect → Benutzer und Zugriff →
#      Integrationen → App Store Connect API. Der Schlüssel selbst liegt schon unter
#      ~/.appstoreconnect/private_keys/AuthKey_9CR8JBB4GT.p8
#
# Aufruf:  ASC_ISSUER_ID=<uuid> ./AppStore/submit.sh
#
set -euo pipefail

KEY_ID="9CR8JBB4GT"
TEAM_ID="NY363CML59"
ARCHIVE="build/SunPos.xcarchive"
EXPORT_DIR="build/export"

if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "ASC_ISSUER_ID ist nicht gesetzt – ohne Issuer-ID kann weder ein" >&2
  echo "Distributionsprofil geholt noch hochgeladen werden." >&2
  exit 1
fi

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
