# Haku Mac implementation contract

macOS 14+, native SwiftUI desktop; SwiftPM HakuMac UI, HakuCore library, haku-mac-probe diagnostic CLI. No external Swift package dependencies. Native device-local capture is never ported to the Mac.

## Core public API (UI implements against this)

`public struct ConnectionProfile: Codable, Equatable, Sendable`: mutable public `name: String = "My iPhone"`, `host: String = "127.0.0.1"`, `sshPort: Int = 2222`, `username: String = "mobile"`, `identityFile: String = ""`, `knownHostsFile: String = "~/.ssh/known_hosts"`, `serverPort: Int = 57042`, `hakuPath: String = "/var/jb/Applications/Haku.app/Haku"`, `remoteOutputRoot: String = "/var/mobile/Media/HakuMac"`; `public init()`.

`public struct DeviceApplication: Codable, Identifiable, Hashable, Sendable`: `identifier: String`, `name: String`, `pid: Int`, `id: String { identifier }`; decode actual on-device list JSON (inspect haku/Sources/HakuEngine.m).

`public struct USBDevice: Identifiable, Hashable, Sendable`: `id: String`, `name: String`.

`public struct ExportResult: Sendable`: `directory: URL`, `reportURL: URL`, `ipaURL: URL?`, `status: String`, `fullyVerified: Bool`, `sha256Verified: Bool`, `zipVerified: Bool`, `summary: String`.

`public final class HakuClient: @unchecked Sendable` with `public init()` and methods:
- `func checkConnection(_ profile: ConnectionProfile) async throws -> String` (actual SSH Haku --connection AND --list reachability or server status; explicitly endpoint configuration alone isn't live server health).
- `func applications(_ profile: ConnectionProfile) async throws -> [DeviceApplication]`
- `func export(_ app: DeviceApplication, profile: ConnectionProfile, destination: URL, progress: @escaping @Sendable (String) -> Void) async throws -> ExportResult`
- `func cancel() async` (cancel current export; send scoped remote signal, never kill all Haku processes)
- `func discoverUSBDevices() async throws -> [USBDevice]`
- `func startUSBForward(device: USBDevice, localPort: Int, remotePort: Int) async throws` (iproxy path discover /opt/homebrew/bin or /usr/local/bin; no bootstrapping install)
- `func stopUSBForward()`

Core writes each run in a unique new local subdirectory under destination; report/error artifacts retained on failure. Use strict host-key checking, BatchMode, key/agent; no passwords/keys persisted by app. Shell quoting of remote arguments mandatory, local Process arguments explicit. Enforce finite timeout for control calls; stream stderr progress. Output success requires report semantic checks plus local SHA256/ZIP verification; never promote partial to fully verified. Cancellation failure must be explicit. No fabricated data in production. UI owns @MainActor AppModel and persists user-entered profile metadata only.

UI: polished cream/yellow/pink/ink Japanese manga style with supplied Resources/haku-chestnut.png mascot; native desktop 3-column/adaptive split composition, connection profile/editor, USB discovery + selected device forwarding, searchable apps, selected details, export/destination/progress/cancel/output reveal, readable errors. English labels. No demo rows. App-wide model shared across window/settings; settings can be sheet. Export is disabled during operation and without connected selection. Display clear remote engine prerequisite and SSH trust setup.

Build/repo/docs owned by lead; UI agent owns Sources/HakuMac excluding precreated mascot; core agent owns Sources/HakuCore, Tests/HakuCoreTests, Sources/HakuMacProbe. Do not edit existing sibling repos or access active phone yet. Communicate proposed interface changes.
