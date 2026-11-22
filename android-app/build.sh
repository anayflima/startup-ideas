#!/bin/bash
# Builds the Pavoot Hours Android app (no Gradle): aapt2 + javac + d8 + apksigner.
# Needs JDK 17 and an Android SDK with platforms;android-36 and build-tools;36.0.0 (SDK env var, default /work/sdk).
# Signing: KEYSTORE (default ./pavoot-hours.jks) with KS_PASS; created on first run. An update must use the same key.
set -euo pipefail
cd "$(dirname "$0")"
SDK="${SDK:-/work/sdk}"; BT="$SDK/build-tools/36.0.0"; JAR="$SDK/platforms/android-36/android.jar"
KEYSTORE="${KEYSTORE:-pavoot-hours.jks}"; KS_PASS="${KS_PASS:-pavoothours}"
rm -rf out && mkdir -p out/cls out/dex
"$BT/aapt2" compile --dir res -o out/res.zip
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml -o out/base.apk --java out/gen out/res.zip --auto-add-overlay
javac -source 17 -target 17 -encoding UTF-8 -nowarn -classpath "$JAR" -d out/cls $(find src out/gen -name '*.java') 2>&1 | grep -v '^Note:' || true
[ -f out/cls/ch/pavoot/hours/MainActivity.class ] || { echo JAVAC_FAILED; exit 1; }
"$BT/d8" --release --min-api 26 --lib "$JAR" --output out/dex $(find out/cls -name '*.class')
cp out/base.apk out/unsigned.apk
(cd out/dex && zip -q -j ../unsigned.apk classes.dex)
"$BT/zipalign" -f -p 4 out/unsigned.apk out/aligned.apk
[ -f "$KEYSTORE" ] || keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias hours -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Pavoot Hours, O=Pavoot Inc.' >/dev/null 2>&1
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:"$KS_PASS" --out out/pavoot-hours.apk out/aligned.apk
"$BT/apksigner" verify out/pavoot-hours.apk && echo "APK OK: $(pwd)/out/pavoot-hours.apk"
