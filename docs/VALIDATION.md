# Validation

## Host build and controlled tests

Validated on macOS 26.4, Apple Silicon, Swift 6.3.3, 2026-10-21. Minimum deployment target is macOS 14; older supported OS versions and Intel have not been exercised.

- `swift build`: passed for the native app, core library, and diagnostic probe.
- `swift test`: 12 tests passed, 0 failures. Coverage includes actual application JSON schema, strict SSH arguments, shell-quoting injection roundtrip, concurrent stdout/stderr draining, command timeout, live-list requirement for health, failed-report retention, capture-report semantics, streamed SHA256, ZIP truncation rejection, optional byte-metric extraction, and confirmed/unconfirmed/local cancellation semantics.
- `script/build_and_run.sh --verify`: real `.app` staging, ad-hoc signing, strict signature verification, and process launch passed.
- Actual Mac accessibility-tree and screenshot inspection confirmed the manga layout, packaged mascot, connection editor, empty-state behavior, and disabled export before prerequisites.

## Physical iPhone, read-only

Using the pre-existing trusted USB SSH endpoint, both the shared-core probe and native GUI connected to the actual on-device Haku/haku-server pair on Haku port 57042. The GUI initially loaded 44 real applications, then 45 after a separate QA app was installed by the coordinated phone-validation task. USB discovery exposed the attached phone in the native device picker. The GUI started its own isolated USB forwarding port, connected and listed 45 apps through that tunnel, and stopped only that tunnel successfully. These checks did not launch or capture a target.

A negative live trust check using an empty host-key store exited with SSH status 255 and `Host key verification failed`; the app did not silently accept the phone key.

## Physical iPhone, capture and cancellation

The final installed Haku 0.2.2 client (`ac6a3b91bd7765d80dc5a9e9f96c15ea79b93adb`) and haku-server `17.24.3+haku.2` were exercised through `haku-mac-probe`, which invokes the same HakuCore implementation as the GUI.

- Completed export: phone report status `verified`, `main_verified`, `fully_verified` and `zip_verified` true. The bundle contained **20,628,414 bytes**, its declared encrypted ranges and captured encrypted ranges were both **4,096 bytes**, and the IPA was **16,297,676 bytes**. These measure different things.
- Local streamed retrieval completed. SHA256 matched the phone report. The app's `unzip -t` check passed, and a separate Python ZIP CRC pass validated all **60 entries**. The report's IPA size matched the actual local file size.
- A separate, longer capture received a scoped SIGINT cancellation after two seconds. The retrieved phone report said `cancelled`, full/main verification remained false, and there was no cleanup error. No IPA was produced or downloaded. The UUID-scoped remote control/PID directory was removed after the owned CLI exited. The probe returned its expected non-success status 3.
- Private reports, archives, logs and phone identifiers remain outside this repository. Remote partial evidence is retained for recovery.

## Source and package

Server source is pinned at `1a30e4b07c059a22787b27c257baf74ee63e54b3` (`17.24.3+haku.2`). The optimized arm64 app/ZIP builds with strict ad-hoc signature verification. The bundle contains source/server revision metadata and license notices.

The live capture and cancellation tests above exercised the shared transport through the diagnostic probe. The native GUI's actual connection, list, search/editor and USB discovery/start/connect/stop paths were observed separately. The final revised metric/result labels were compiled and reviewed in source; no new GUI export/cancel click is claimed for that revision.

## Acceptance boundaries

Report/native-image verification, local artifact hash/ZIP integrity, iOS signing, installation, ordinary launch, and app functionality are separate claims. Haku Mac's result view explicitly retains that distinction. Unknown/changed SSH host keys fail closed. The package is ad-hoc signed for local use and is not notarized.
