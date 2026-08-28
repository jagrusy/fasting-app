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

## 2. Add Secrets to GitHub Repository

In your GitHub repository ([jagrusy/fasting-app](https://github.com/jagrusy/fasting-app)):
1. Go to **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
2. Click **New repository secret** and add the following:

| Secret Name | Description / Value |
| :--- | :--- |
| `APP_STORE_CONNECT_KEY_ID` | Your App Store Connect Key ID (e.g. `2X9R4HXF34`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Your Issuer ID UUID |
| `APP_STORE_CONNECT_KEY_CONTENT` | The Base64-encoded `.p8` key or direct text contents |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (10-character alphanumeric) |

> [!TIP]
> To Base64-encode your `.p8` key on Mac terminal, run:
> ```bash
> base64 -i AuthKey_XXXXXX.p8 | pbcopy
> ```
> This copies the base64 string directly to your clipboard to paste into GitHub Secrets.

---

## 3. How to Deploy

### Option A: Manual Trigger via GitHub Actions UI
1. Go to the **Actions** tab in GitHub.
2. Select **Deploy to TestFlight & App Store**.
3. Click **Run workflow**, choose `beta` (for TestFlight) or `release` (for App Store Review), and click **Run**.

### Option B: Push a Git Release Tag
Pushing any git tag starting with `v` (e.g. `v1.0.0`) automatically triggers the build and uploads it to TestFlight:
```bash
git tag v1.0.0
git push --tags
```

### Option C: Build Locally (no CI secrets required)
Both options above run in GitHub Actions and need the CI secrets in step 2 configured with a
valid **distribution certificate** — `get_provisioning_profile` can bind an existing certificate
to a profile, but it can't create one from nothing on a bare CI runner. If that hasn't been set
up yet (or you just want a quick TestFlight build without waiting on CI), build and upload from
your own Mac instead. This uses the Apple ID already signed in to Xcode (Xcode → Settings →
Accounts) to sign and upload, so no App Store Connect API key or CI secrets are involved:

```bash
APPLE_TEAM_ID=ABCDE12345 make beta-local
```

(Find your team ID at [developer.apple.com/account](https://developer.apple.com/account) under
Membership.) The first run will prompt for your Apple ID and 2FA code; after that, fastlane
reuses your local session. This is the `beta_local` lane in `fastlane/Fastfile`.
