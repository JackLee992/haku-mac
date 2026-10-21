import Foundation
import HakuCore

@main struct Probe {
  static func main() async {
    do {
      var p = ConnectionProfile()
      let env = ProcessInfo.processInfo.environment
      p.host = env["HAKU_HOST"] ?? p.host
      p.username = env["HAKU_USER"] ?? p.username
      p.identityFile = env["HAKU_IDENTITY"] ?? p.identityFile
      p.knownHostsFile = env["HAKU_KNOWN_HOSTS"] ?? p.knownHostsFile
      p.hakuPath = env["HAKU_PATH"] ?? p.hakuPath
      p.remoteOutputRoot = env["HAKU_REMOTE_ROOT"] ?? p.remoteOutputRoot
      p.sshPort = Int(env["HAKU_SSH_PORT"] ?? "2222") ?? 2222
      p.serverPort = Int(env["HAKU_SERVER_PORT"] ?? "57042") ?? 57042
      let args = Array(CommandLine.arguments.dropFirst())
      let client = HakuClient()
      switch args.first ?? "help" {
      case "check": print(try await client.checkConnection(p))
      case "list":
        let apps = try await client.applications(p)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(apps), as: UTF8.self))
      case "usb":
        for device in try await client.discoverUSBDevices() {
          print("\(device.id)\t\(device.name)")
        }
      case "export", "cancel-test":
        guard args.count >= 3 else {
          throw HakuError(
            "Usage: export BUNDLE DESTINATION | cancel-test BUNDLE DESTINATION [SECONDS]")
        }
        let apps = try await client.applications(p)
        guard let app = apps.first(where: { $0.identifier == args[1] }) else {
          throw HakuError("Application not found")
        }
        var cancellation: Task<Void, Never>?
        if args[0] == "cancel-test" {
          let seconds = Double(args.count > 3 ? args[3] : "2") ?? 2
          cancellation = Task {
            do { try await Task.sleep(nanoseconds: UInt64(max(0.1, seconds) * 1e9)) } catch {
              return
            }
            guard !Task.isCancelled else { return }
            await client.cancel()
          }
        }
        defer { cancellation?.cancel() }
        let result = try await client.export(
          app, profile: p, destination: URL(fileURLWithPath: args[2])
        ) { text in FileHandle.standardError.write(Data(text.utf8)) }
        print(result.summary)
        print(result.directory.path)
        if !result.fullyVerified { exit(3) }
      default:
        print(
          "haku-mac-probe check | list | usb | export BUNDLE DESTINATION | cancel-test BUNDLE DESTINATION [SECONDS]\nConfiguration: HAKU_HOST, HAKU_USER, HAKU_SSH_PORT, HAKU_SERVER_PORT, HAKU_IDENTITY, HAKU_KNOWN_HOSTS, HAKU_PATH, HAKU_REMOTE_ROOT. Export is explicitly opt-in."
        )
      }
    } catch {
      FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
      exit(1)
    }
  }
}
