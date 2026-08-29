# Solstice — Fastlane & GitHub Actions Setup Guide

This guide explains how to configure automated TestFlight and App Store releases for Solstice.

---

## 1. Generate App Store Connect API Key

Apple provides official API Keys for CI/CD authentication without 2FA SMS prompts:

1. Log in to [App Store Connect](https://appstoreconnect.apple.com).
2. Navigate to **Users and Access** $\rightarrow$ **Integrations** $\rightarrow$ **App Store Connect API**.
3. Click the **+** (Generate API Key) button:
   - **Name**: `Solstice Fastlane CI`
   - **Access / Role**: `App Manager` (or `Developer`)
4. Once generated, note down:
   - **Key ID** (e.g. `2X9R4HXF34`)
   - **Issuer ID** (e.g. `69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
5. Click **Download API Key** to download the private key file (`AuthKey_XXXXXX.p8`).
   *(⚠️ Note: Apple only allows downloading this file once!)*

---

## 2. Set Up Code Signing (match)

This is the step that was missing before: CI has an App Store Connect API key (step 1), but no
**distribution certificate**. `get_provisioning_profile`/`sigh` can bind an existing certificate
to a profile, but can't create one from nothing on a brand-new, empty CI runner — that's why
every automated deploy has failed so far. [`fastlane match`](https://docs.fastlane.tools/actions/match/)
fixes this by generating the certificate and profile **once, from your own Mac**, encrypting
them, and storing them in a private git repo that CI reads from (read-only — CI never creates or
revokes certificates).

1. **Create a new private GitHub repository** to hold the encrypted certificates, e.g.
   `jagrusy/fasting-app-certificates`. Nothing needs to go in it — `match` initializes it.
2. **Point the project at it.** Open `fastlane/Matchfile` and replace the placeholder URL with
   that repo's URL (or just export `MATCH_GIT_URL` before running the commands below instead of
   editing the file).
3. **Generate the certificate and profile**, from your own Mac (this needs your interactive
   Apple ID / 2FA — it can't be scripted or done by an agent):
   ```bash
   bundle exec fastlane match appstore
   ```
   You'll be asked to set a passphrase — this encrypts everything stored in the certs repo.
   **Save that passphrase**, you'll need it again in step 4.
4. **Create a GitHub Personal Access Token** so CI can read the private certs repo: on GitHub,
   **Settings → Developer settings → Personal access tokens → Tokens (classic)**, scope: `repo`.
   Then base64-encode `username:token` for match's basic-auth format:
   ```bash
   echo -n "jagrusy:ghp_yourTokenHere" | base64
   ```

---

## 3. Add Secrets to GitHub Repository

In your GitHub repository ([jagrusy/fasting-app](https://github.com/jagrusy/fasting-app)):
1. Go to **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
2. Click **New repository secret** and add the following:

| Secret Name | Description / Value |
| :--- | :--- |
| `APP_STORE_CONNECT_KEY_ID` | Your App Store Connect Key ID (e.g. `2X9R4HXF34`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Your Issuer ID UUID |
| `APP_STORE_CONNECT_KEY_CONTENT` | The Base64-encoded `.p8` key or direct text contents |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (10-character alphanumeric) |
| `MATCH_PASSWORD` | The passphrase you chose in step 2.3 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | The base64 string from step 2.4 |

> [!TIP]
> To Base64-encode your `.p8` key on Mac terminal, run:
> ```bash
> base64 -i AuthKey_XXXXXX.p8 | pbcopy
> ```
> This copies the base64 string directly to your clipboard to paste into GitHub Secrets.

---

## 4. How to Deploy

### Automatic: on every merge to `main`
Every push to `main` now runs the `beta` lane automatically — build, sign, and upload to
TestFlight. No action needed once steps 1–3 above are done.

### Automatic: on a release tag
Pushing any git tag starting with `v` (e.g. `v1.0.0`) runs the `release` lane — uploads metadata,
screenshots, and submits the build for App Store review:
```bash
git tag v1.0.0
git push --tags
```

### Manual Trigger via GitHub Actions UI
1. Go to the **Actions** tab in GitHub.
2. Select **Deploy to TestFlight & App Store**.
3. Click **Run workflow**. Leave the lane blank to let it auto-select (same rule as above), or
   force `beta` / `release` explicitly.

### Build Locally (no CI secrets required)
All three options above run in GitHub Actions and need steps 1–3 done first. If that hasn't
happened yet, or you just want a quick TestFlight build without waiting on CI, build and upload
from your own Mac instead. This uses the Apple ID already signed in to Xcode (Xcode → Settings →
Accounts) to sign and upload, so no App Store Connect API key, match, or CI secrets are involved:

```bash
APPLE_TEAM_ID=ABCDE12345 make beta-local
```

(Find your team ID at [developer.apple.com/account](https://developer.apple.com/account) under
Membership.) The first run will prompt for your Apple ID and 2FA code; after that, fastlane
reuses your local session. This is the `beta_local` lane in `fastlane/Fastfile`.

**First-time `bundle install` on macOS with Homebrew's Ruby:** if it fails with a
`Bundler::PermissionError` writing to `/opt/homebrew/lib/ruby/gems/...`, that directory is
owned by `root` and bundler won't fall back to a user-writable path on its own. Point it at a
project-local one instead (one-time, per machine):
```bash
bundle config set --local path 'vendor/bundle'
bundle install
```
