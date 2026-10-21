# Architecture

Haku Mac is an independent macOS desktop companion for the Haku iOS client and its dedicated haku-server. The phone's Haku engine requires access to phone-local installed bundles, native image memory, and phone process control. Those requirements stay on the phone. A server-only desktop exporter would require a new authenticated remote filesystem and capture protocol; the existing server does not provide that end-to-end API.

```text
SwiftUI Mac app → HakuCore → system OpenSSH → on-device Haku CLI
                                                  ↓
                                   127.0.0.1:<haku port> → haku-server
                                                  ↓
                                         report.json + export.ipa
SwiftUI result ← local hash/ZIP verification ← SSH artifact transfer
```

USB support manages an optional iproxy child targeting a selected usbmux device. LAN and pre-existing USB tunnels use the same explicit SSH endpoint configuration. The Haku server port is a separate value: default 57042 on the phone, unrelated to the SSH tunnel port. Original Frida ports 27042/27043 remain independent.

The transport has no hardcoded app allowlist or install-directory filter. The application list comes from the phone's Haku CLI. Selecting an app is a deliberate capture operation and uses the phone engine's process lifecycle semantics.

## Boundaries

- Trust is anchored in a user-selected OpenSSH known_hosts file; unknown or changed host keys fail closed. Key/agent authentication is non-interactive. Key contents are never read by the application or saved in preferences.
- Output directories are unique per operation. Failed/partial reports and logs are retained rather than represented as success.
- Remote report claims and local transport validation remain distinguishable. A matching IPA SHA256 and a valid ZIP do not establish signing, installation, ordinary launch, or business-function acceptance.
- Cancellation targets only the remote command created for this operation and relies on Haku CLI signal cancellation support. Losing connectivity cannot prove remote cleanup. Remote output is retained for recovery.
- The server Git submodule records source provenance; it is not compiled or required to build the desktop companion.

## Source map

- `Sources/HakuCore`: connection configuration, transport, protocol parsing, artifact verification.
- `Sources/HakuMac`: app lifecycle, state, native SwiftUI views and mascot.
- `Sources/HakuMacProbe`: diagnostic console entry point using the same transport.
- `Tests/HakuCoreTests`: controlled parser/transport/verifier regressions.
- `script/build_and_run.sh`: reproducible app staging, launch and local packaging.
