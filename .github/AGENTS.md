# Build, release and policy changes

- Never execute untrusted PR code with publishing credentials. Use read-only default token permissions and only the job permissions required.
- Distribution must bind to the exact trusted commit's successful complete checks. Missing, skipped, stale, failed or cancelled checks are not green.
- Production requires an explicit human decision. Verify live environment protection; naming an environment in YAML alone does not prove approval is enforced.
- Human approval must identify what is submitted and published. Do not substitute a different build or claim source-level approval proves binary promotion; promotion of the tested TestFlight artifact is separate tracked work until implemented.
- Keep per-target signing and bundle/version alignment. Signing diagnostics must not upload. Never log credentials/profile contents or relax a gate merely to diagnose signing.
- Use policy decision fixtures and failure cases for workflow changes. Validate YAML/action syntax; app tests are needed only if affected behavior requires them. Record remote checks/settings that cannot be verified.
- An agent cannot change the trusted classifier to waive review for its own PR. No automatic merge until server-side protections and limited identities are verified.
