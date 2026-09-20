# Shared commands and Apple surfaces

- This source is consumed by multiple app/extension targets. Compile every affected iOS/watchOS consumer after a contract change.
- A wire-format change defines schema version, explicit time/duration units, stable command/session identity, reset generation, outcomes and revision reconciliation. Keep a deliberate legacy-decoding policy.
- Commands must survive crashes until their effect/rejection is durable. Deduplication must survive relaunch; an in-memory set and process-local lock alone are insufficient.
- Widgets and Watch cannot depend on the phone UI being alive. Show pending/rejected work honestly; reconcile optimistic presentation to authoritative state.
- Do not generalize fasting biology into a generic wellness/session framework. Extract only demonstrated shared behavior.
