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

## 2. Set Up Code Signing (certificate secret)

This is the step that was missing before: CI has an App Store Connect API key (step 1), but no
**distribution certificate**. `get_provisioning_profile`/`sigh` can bind an existing certificate
to a profile, but can't create one from nothing on a brand-new, empty CI runner — that's why
every automated deploy has failed so far. The certificate has to be generated once by a human
with Apple Developer access (no way around that part), but from there it's just a file: export
it, base64-encode it, and drop it straight into a GitHub secret. CI decodes it into a keychain
that exists only for that one job run and is destroyed with the runner afterward.

1. **Create the certificate**, if you don't already have one: Xcode → Settings → Accounts →
   select your team → **Manage Certificates** → **+** → **Apple Distribution**. (Skip if
   `security find-identity -v -p codesigning` already shows an Apple Distribution identity.)
2. **Export it as a `.p12`**: open Keychain Access → **My Certificates** → find the
   "Apple Distribution: ..." entry → right-click → **Export** → save as `Certificates.p12` →
   set a password when prompted. **Save that password**, you'll need it again in step 4.
3. **Base64-encode it**:
   ```bash
   base64 -i Certificates.p12 | pbcopy
   ```
   That's now on your clipboard, ready to paste into a GitHub secret.

---

## 3. Add Secrets to Protected GitHub Environments

In your GitHub repository ([jagrusy/fasting-app](https://github.com/jagrusy/fasting-app)):
1. Go to **Settings → Environments** and configure `testflight` and `production` as described below before adding credentials.
2. Add signing/publishing credentials as **environment secrets** in each environment that needs them. Do not use repository or organization secrets for these credentials: a branch workflow could reference those without this deployment gate.
3. Remove any existing repository/organization copies after the protected environment setup is verified. Do not print, copy into source, or rotate credentials as part of an agent implementation task. The owner performs this configuration separately.

| Secret Name | Description / Value |
| :--- | :--- |
| `APP_STORE_CONNECT_KEY_ID` | Your App Store Connect Key ID (e.g. `2X9R4HXF34`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Your Issuer ID UUID |
| `APP_STORE_CONNECT_KEY_CONTENT` | The Base64-encoded `.p8` key or direct text contents |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (10-character alphanumeric) |
| `BUILD_CERTIFICATE_BASE64` | The base64 string from step 2.3 |
| `P12_PASSWORD` | The password you set exporting the `.p12` in step 2.2 |
| `APP_REVIEW_PHONE` | A phone number Apple's App Review team can reach you at (e.g. `+15551234567`) — only needed for the `release` lane, not `beta` |

> [!TIP]
> To Base64-encode your `.p8` key on Mac terminal, run:
> ```bash
> base64 -i AuthKey_XXXXXX.p8 | pbcopy
> ```
> This copies the base64 string directly to your clipboard to paste into GitHub Secrets.

---

## 4. One-Time App Store Connect Setup (before the first `release`)

Solstice has only ever gone through TestFlight, never a real App Store review — TestFlight
doesn't enforce a few things that App Store review does. These are one-time, per-app settings
that live in the App Store Connect **web UI only**; there's no fastlane action or metadata file
that can set them, so no amount of CI automation can skip this part. Do these once, before the
first protected manual `release` run, at [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
→ your app:

- [ ] **Age Rating** — App Store Connect will prompt for the age-rating questionnaire the first
  time you touch the app's version page.
- [ ] **App Privacy ("Nutrition Label")** — under the **App Privacy** section, declare what data
  the app collects. For Solstice this should be straightforward: it's 100% on-device with no
  accounts, no analytics, and no network calls, so the honest answer is "we don't collect data."
- [ ] **Pricing and Availability** — set a price tier (or Free) and which territories it's
  available in.

`deliver` (the `release` lane) will fail with a clear error pointing at whichever of these is
still missing — it's safe to just try the lane and let the error tell you what's left.

Two things that are *already* handled and won't ask you anything:
- **Export compliance** — `Fasted/Info.plist` already declares
  `ITSAppUsesNonExemptEncryption = false`, so Apple won't prompt for this per-submission.
- **App Review contact info** — set automatically by the `release` lane from
  `APP_REVIEW_PHONE`/`APP_REVIEW_EMAIL`/etc. above; Solstice has no accounts, so there's no demo
  login to provide either.
- **Privacy Manifest** — `Fasted/PrivacyInfo.xcprivacy` declares the app's `UserDefaults` usage
  (used only for preferences like a fast's snooze delay, never shared). This is a
  separate, newer Apple requirement from the App Privacy page above — it's a file in the app
  binary that Apple's automated binary validation checks, catching apps that skip it before a
  human ever reviews the submission.

---

## 5. Verified deployment flow

A successful **main-push CI** run triggers automatic TestFlight distribution. The deployment
preflight verifies the CI workflow identity, exact current-main SHA, latest run/attempt, and
successful `SwiftLint`, `Build & Test`, `Release Policy Tests`, and `CI Required` jobs. It
rechecks before signing. PR runs, tag pushes, skipped checks and `skip_tests` cannot authorize
an upload. If main advances before verification/approval, wait for its CI and dispatch again.

### One-time environment protection (required before any upload)

Create both `testflight` and `production`. In each environment, select **Selected branches and tags** and add exactly one **branch** rule named `main`. Do not add tag rules, wildcards, or PR refs. Do not choose **Protected branches only**: GitHub permits all branches under that option when no branch protection exists. The preflight checks the selected environment's identity, policy mode, and complete branch-rule listing both before admitting the publish job and again before signing. Missing, ambiguous or unreadable settings block distribution. Automatic beta checks only `testflight`; it does not depend on production configuration.

In repository Settings → Environments, configure `production` with a required **human User**
reviewer whose login is in the `RELEASE_ACTORS` Actions variable. The allowlist defaults to the
repository owner if unset; use comma-separated logins when explicitly adding operators.
Disable administrator bypass in both environments. A solo owner may
need self-review permitted to approve their own manually dispatched run; review remains an
explicit separate action. Do not add a bot as the required reviewer.

The preflight refuses a missing/unprotected environment, then the publishing job waits on
that environment. After the wait, it verifies actual approval history by an allowed human.
A production rerun cannot reuse an earlier approval; dispatch a new run. Configure any
credential changes separately—never put signing material into the repository. The documented
environment REST response does not expose administrator-bypass configuration; inspect that
setting in GitHub and record evidence separately. The policy verifies an actual allowlisted
human approval before signing but does not claim this proves every server-side setting.

The absence of repository/organization credential copies also requires separate owner verification;
the read-only Actions token does not audit secret configuration. Branch restrictions do not
replace reviewed main-branch changes: require CI and approving PR review before enabling
autonomous merges. See [GitHub environment protection and secret behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
and [deployment branch-policy API](https://docs.github.com/en/rest/deployments/branch-policies).

### Manual distribution

1. Find the successful main-push CI run for the **current** main commit.
2. Open **Deploy to TestFlight & App Store → Run workflow**, selecting branch `main`.
3. Supply `lane` (`beta`, `release`, or `screenshots_upload`), numeric `ci_run_id`, and the
   full 40-character `commit_sha` from that CI run.
4. For production lanes, inspect the verified source/CI summary and approve only if submission
   and publication are intended. An App Store `release` still uses `automatic_release: true`
   after Apple review; approval is not merely permission to build.

**Current boundary:** this change binds distribution to a tested source commit. The existing
release lane still archives separately from beta. It does **not** yet promote the exact
TestFlight binary; artifact promotion remains separate tracked work. Do not describe this as
binary promotion or approve it under that assumption. Toolchain pinning also remains separate
tracked work. Never substitute a commit after approval.

Local app/simulator builds remain available. Direct `beta`, `release`, or screenshot-upload
lane invocation now requires the verified workflow context. `beta_local` / `make beta-local`
intentionally fail instead of bypassing CI. Use Xcode for local development without uploading.

### Verify release-policy changes locally

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
ruby fastlane/tests/release_guard_test.rb
ruby -c fastlane/Fastfile
```

These tests use synthetic API responses and do not sign, upload, or submit an app. Hosted CI,
configured environment protection, and a real approval event still need separate verification.

**First-time `bundle install` on macOS with Homebrew's Ruby:** if it fails with a
`Bundler::PermissionError` writing to `/opt/homebrew/lib/ruby/gems/...`, that directory is
owned by `root` and bundler won't fall back to a user-writable path on its own. Point it at a
project-local one instead (one-time, per machine):
```bash
bundle config set --local path 'vendor/bundle'
bundle install
```
