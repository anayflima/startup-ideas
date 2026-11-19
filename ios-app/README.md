# Pavoot Hours for iPhone

Native iPhone app (Swift, WKWebView) that opens the live Pavoot Hours web app, so it always has the same features and data as the web and Android versions. Bundle ID `ch.pavoot.hours`.

Built on GitHub's macOS runners by `.github/workflows/ios.yml` (Actions > iOS app (TestFlight) > Run workflow):
- `upload` off: compile check only (simulator build, no signing).
- `upload` on: signs automatically and uploads to TestFlight.

## One-time setup in the Apple Developer account
1. App Store Connect > Apps > + New App: iOS, name Pavoot Hours, bundle ID `ch.pavoot.hours` (register it under Certificates, IDs & Profiles > Identifiers if it is not listed), SKU `pavoot-hours`.
2. App Store Connect > Users and Access > Integrations > App Store Connect API > Team Keys: generate a key with Admin access, download the .p8 (only downloadable once), note the Key ID and Issuer ID.
3. Team ID: developer.apple.com > Account > Membership details.
4. GitHub repo secrets (Settings > Secrets and variables > Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the .p8 file contents), `APPLE_TEAM_ID`.
5. Run the workflow with upload on. In TestFlight, add Ana and Gohar as internal testers; they install the TestFlight app and then Pavoot Hours.
