# GitHub Actions release workflow (signed + notarized DMG)

End-to-end pipeline: push trigger → fetch certs from secrets → build Release → notarize via Apple → DMG → GitHub Release.

## Prerequisites

1. **Apple Developer Program membership** ($99/year)
2. **Developer ID Application certificate** — *not* Apple Development, *not* Apple Distribution. The exact one. Created from https://developer.apple.com/account/resources/certificates/list, "Software" section, "Developer ID Application", G2 Sub-CA (Xcode 11.4.1+).
3. **App-specific password** generated at https://account.apple.com/account/manage → Sign-In and Security → App-Specific Passwords.
4. The cert installed in your Keychain *and* exported as `.p12` with the private key.

## Required GitHub Secrets

Set via the web UI (Settings → Secrets and variables → Actions) or via `gh` CLI:

| Secret | Value |
|---|---|
| `CERTIFICATE_P12` | `base64 -i Certificate.p12` |
| `CERTIFICATE_PASSWORD` | password used when exporting the `.p12` |
| `APPLE_ID` | your Apple ID email |
| `APPLE_ID_PASSWORD` | the app-specific password (`xxxx-xxxx-xxxx-xxxx`) |
| `APPLE_TEAM_ID` | your 10-character Apple Team ID (public, but stored as secret for hygiene) |

CLI route is faster — no copy-paste:

```bash
# Export cert as .p12 from Keychain Access (right-click → Export)
# Or programmatically:
security export -k login.keychain-db -t identities -f pkcs12 -P "<random-password>" -o ~/Downloads/signing.p12

# Set secrets
P12_BASE64=$(base64 -i ~/Downloads/signing.p12)
gh secret set CERTIFICATE_P12 -R owner/repo -b "$P12_BASE64"
gh secret set CERTIFICATE_PASSWORD -R owner/repo -b "<random-password>"
gh secret set APPLE_ID -R owner/repo
gh secret set APPLE_ID_PASSWORD -R owner/repo
gh secret set APPLE_TEAM_ID -R owner/repo
```

## Workflow file

`.github/workflows/release.yml`:

```yaml
name: Release App

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version number (e.g., 1.0.0)'
        required: true
        type: string

permissions:
  contents: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-release:
    name: Build DMG and Create Release
    runs-on: macos-26
    env:
      VERSION: ${{ inputs.version }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '26'

      - name: Install certificate
        env:
          CERTIFICATE_P12: ${{ secrets.CERTIFICATE_P12 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
          KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          echo "$CERTIFICATE_P12" | base64 --decode > "$RUNNER_TEMP/certificate.p12"
          security import "$RUNNER_TEMP/certificate.p12" -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH"

      - name: Set marketing version
        run: |
          xcrun agvtool new-marketing-version "$VERSION"
          xcrun agvtool new-version -all "$VERSION"

      - name: Build
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcodebuild -project App.xcodeproj \
            -scheme App \
            -configuration Release \
            -derivedDataPath build \
            DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            CODE_SIGN_STYLE=Manual \
            ENABLE_HARDENED_RUNTIME=YES \
            CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
            OTHER_CODE_SIGN_FLAGS="--timestamp" \
            build

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          APP_PATH="build/Build/Products/Release/App.app"
          ditto -c -k --keepParent "$APP_PATH" App-notarize.zip
          SUBMISSION_OUTPUT=$(xcrun notarytool submit App-notarize.zip \
            --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" --team-id "$APPLE_TEAM_ID" \
            --wait 2>&1)
          echo "$SUBMISSION_OUTPUT"
          SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
          if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
            echo "Notarization successful!"
          else
            xcrun notarytool log "$SUBMISSION_ID" --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" --team-id "$APPLE_TEAM_ID"
            exit 1
          fi
          xcrun stapler staple "$APP_PATH"

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Create DMG
        run: |
          create-dmg \
            --volname "App" \
            --window-pos 200 120 --window-size 660 420 \
            --icon-size 100 \
            --icon "App.app" 170 200 --hide-extension "App.app" \
            --app-drop-link 490 200 \
            "App-${VERSION}.dmg" \
            "build/Build/Products/Release/App.app"

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          name: "App v${{ inputs.version }}"
          tag_name: "v${{ inputs.version }}"
          generate_release_notes: true
          files: App-*.dmg
          draft: false
          prerelease: false
          make_latest: true
```

## Companion CI workflow

`.github/workflows/ci.yml` — verify every push to main builds:

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build (Debug)
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: '26' }
      - name: Build (no codesign)
        run: |
          xcodebuild -project App.xcodeproj \
            -scheme App \
            -configuration Debug \
            -destination 'platform=macOS' \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build
```

## Cutting a release

```bash
gh workflow run release.yml -R owner/repo -f version=1.0.0
gh run watch -R owner/repo
```

Takes ~10–15 minutes:
- ~30s: setup
- ~3–5m: build
- ~3–10m: Apple notarization (varies by queue)
- ~30s: stapler + DMG + release publish

DMG appears at `https://github.com/owner/repo/releases/latest`.

## Triggering on push (auto-release on every main commit)

Replace the trigger with a push trigger and use a date or git-sha-based version:

```yaml
on:
  push:
    branches: [main]
    paths-ignore:
      - 'README.md'
      - 'docs/**'

env:
  VERSION: $(date +%Y.%m.%d)-$(echo $GITHUB_SHA | cut -c1-7)
```

But notarization is slow (~5min minimum) and expensive — every push triggering a release is overkill. Most apps use:
- `workflow_dispatch` for manual versioned releases
- CI workflow for compile-only check on push

## Anti-patterns

- ❌ Inlining `${{ inputs.version }}` directly in a `run:` script — use `env: VERSION: ${{ inputs.version }}` and reference `$VERSION`. GitHub Actions hook will flag this.
- ❌ Using "Apple Development" certs to sign for distribution — Gatekeeper rejects. Must be Developer ID.
- ❌ Skipping `--timestamp` on `OTHER_CODE_SIGN_FLAGS` — required for notarization
- ❌ Forgetting `xcrun stapler staple` — without it, the app needs internet to verify on first launch
- ❌ Storing the `.p12` file in the repo — even encrypted, it's a no
- ❌ Reusing the same Apple ID password as `APPLE_ID_PASSWORD` — must be an app-specific password from appleid.apple.com

## Verification

After running the workflow:

```bash
# Download DMG
gh release download v1.0.0 -R owner/repo -p '*.dmg'

# Verify signature
codesign -dv --verbose=4 App-1.0.0.dmg
codesign --verify --verbose App.app

# Verify notarization
spctl -a -t install -vv App.app
# Should output: "App.app: accepted (notarized)"

# Verify staple
stapler validate App.app
# Should output: "The validate action worked!"
```

If `spctl` says "rejected" but notarization log was Accepted, double-check the staple step ran. Stapling is what makes the app verifiable offline.
