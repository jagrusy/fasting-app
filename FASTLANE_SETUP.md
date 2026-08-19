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
