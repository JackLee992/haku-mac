# Validation

## Host build and controlled tests

Validated on macOS 26.4, Apple Silicon, Swift 6.3.3, 2026-10-21. Minimum deployment target is macOS 14; older supported OS versions and Intel have not been exercised.

- `swift build`: passed for the native app, core library, and diagnostic probe.
- `swift test`: 10 tests passed, 0 failures. Coverage includes actual application JSON schema, strict SSH arguments, shell-quoting injection roundtrip, concurrent stdout/stderr draining, command timeout, live-list requirement for health, failed-report retention, capture-report semantics, streamed SHA256, and ZIP truncation rejection.
- `script/build_and_run.sh --verify`: real `.app` staging, ad-hoc signing, strict signature verification, and process launch passed.
- Actual Mac accessibility-tree and screenshot inspection confirmed the manga layout, packaged mascot, connection editor, empty-state behavior, and disabled export before prerequisites.

## Physical iPhone, read-only

Using the pre-existing trusted USB SSH endpoint, both the shared-core probe and native GUI connected to the actual on-device Haku/haku-server pair on Haku port 57042. The GUI loaded the real list of 44 applications. This check did not launch or capture a target.

## Pending delivery checks

Export/retrieval/cancellation and the optimized distribution package are awaiting the coordinated physical-device slot. Do not treat the read-only check as capture acceptance.

## Acceptance boundaries

Report/native-image verification, local artifact hash/ZIP integrity, iOS signing, installation, ordinary launch, and app functionality are separate claims. Haku Mac's result view explicitly retains that distinction. Unknown/changed SSH host keys fail closed. The package is ad-hoc signed for local use and is not notarized.
