#!/bin/bash
# Builds the Pavoot Hours iPhone app on a GitHub macOS runner.
# upload=false: checks that it compiles (simulator, no signing).
# upload=true: archives, signs automatically with the App Store Connect API key and uploads to TestFlight.
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
xcodebuild -version
BUILD="${BUILD:-1}"
echo "== Simulator build (no signing) =="
xcodebuild -project PavootHours.xcodeproj -scheme PavootHours -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION="$BUILD" build | tail -n 40
if [ "${UPLOAD:-false}" != "true" ]; then echo "BUILD OK. Run again with upload=true to send it to TestFlight."; exit 0; fi
for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 APPLE_TEAM_ID; do
  if [ -z "${!v:-}" ]; then echo "Missing secret $v (repo Settings > Secrets and variables > Actions)"; exit 1; fi
done
KEY="${RUNNER_TEMP:-/tmp}/AuthKey_${ASC_KEY_ID}.p8"
if printf '%s' "$ASC_KEY_P8" | grep -q 'BEGIN PRIVATE KEY'; then printf '%s\n' "$ASC_KEY_P8" > "$KEY"; else printf '%s' "$ASC_KEY_P8" | base64 --decode > "$KEY"; fi
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
echo "== Archive (signed) =="
xcodebuild -project PavootHours.xcodeproj -scheme PavootHours -configuration Release -destination 'generic/platform=iOS' -archivePath build/PavootHours.xcarchive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" "${AUTH[@]}" archive | tail -n 40
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>$APPLE_TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>manageAppVersionAndBuildNumber</key><false/>
<key>uploadSymbols</key><true/>
</dict></plist>
EOF
echo "== Export + upload to App Store Connect =="
xcodebuild -exportArchive -archivePath build/PavootHours.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/export "${AUTH[@]}" | tail -n 40
echo "UPLOADED build $BUILD. It shows in TestFlight after Apple finishes processing (about 5-30 min)."
