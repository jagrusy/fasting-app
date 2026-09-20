# UI tests

- Each scenario declares fresh/seeded state and uses test-only isolated storage. Assert expected controls before interacting; do not conditionally skip the behavior being tested.
- Verify outcomes: start/end/save -> exact history -> relaunch, rather than accepting either an empty or nonempty history.
- Preserve failure screenshots/xcresults and first-run failures. A passing retry does not erase a flake.
- Test large text, VoiceOver order and reduced motion when changing interaction/design. State simulator limitations and required physical-device checks explicitly.
