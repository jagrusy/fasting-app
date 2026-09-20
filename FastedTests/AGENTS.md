# Unit and integration tests

- Test externally observable behavior and failure boundaries, not copies of implementation logic. Count/line coverage alone is not confidence.
- Isolate defaults, stores, clocks, notification and transport services. Tests must not use the owner's App Group, real notifications or persistent history.
- Use disk-backed fixtures and recreate services for crash/relaunch/upgrade scenarios. Holding the same live manager does not simulate termination.
- Cover stale/duplicate commands, transaction failures, reset generations and denied capabilities when relevant. Keep fixtures traceable to the model/protocol version they represent.
