import AppKit
import HakuCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  @Published var profile: ConnectionProfile {
    didSet {
      saveProfile()
      connected = false
      applications = []
      selectedID = nil
    }
  }
  @Published var applications: [DeviceApplication] = []
  @Published var selectedID: String?
  @Published var search = ""
  @Published var connected = false
  @Published var busy = false
  @Published var exporting = false
  @Published var status = "Ready when you are."
  @Published var logs: [String] = []
  @Published var error: String?
  @Published var result: ExportResult?
  @Published var devices: [USBDevice] = []
  @Published var deviceID: String?
  @Published var forwarding = false
  @Published var showConnection = false
  @Published var destination: URL?
  private let client = HakuClient()
  var selected: DeviceApplication? { applications.first { $0.id == selectedID } }
  var filtered: [DeviceApplication] {
    applications.filter {
      search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
        || $0.identifier.localizedCaseInsensitiveContains(search)
    }
  }
  init() {
    if let data = UserDefaults.standard.data(forKey: "connectionProfile"),
      let value = try? JSONDecoder().decode(ConnectionProfile.self, from: data)
    {
      profile = value
    } else {
      profile = ConnectionProfile()
    }
  }
  private func saveProfile() {
    if let data = try? JSONEncoder().encode(profile) {
      UserDefaults.standard.set(data, forKey: "connectionProfile")
    }
  }
  func connect() {
    guard !busy && !exporting else { return }
    busy = true
    error = nil
    status = "Checking SSH and Haku…"
    let snapshot = profile
    Task {
      defer { busy = false }
      do {
        let message = try await client.checkConnection(snapshot)
        let apps = try await client.applications(snapshot)
        guard profile == snapshot else { return }
        connected = true
        applications = apps
        status = message
      } catch {
        connected = false
        self.error = error.localizedDescription
        status = "Connection needs attention."
      }
    }
  }
  func discover() {
    guard !busy && !exporting else { return }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do {
        devices = try await client.discoverUSBDevices()
        deviceID = devices.first?.id
        status = devices.isEmpty ? "No USB devices found." : "Choose a USB device to forward."
      } catch { self.error = error.localizedDescription }
    }
  }
  func forward() {
    guard let device = devices.first(where: { $0.id == deviceID }), !busy && !exporting else {
      return
    }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do {
        try await client.startUSBForward(device: device, localPort: profile.sshPort, remotePort: 22)
        profile.host = "127.0.0.1"
        forwarding = true
        status = "USB SSH forwarding started. Check connection next."
      } catch { self.error = error.localizedDescription }
    }
  }
  func stopForward() {
    client.stopUSBForward()
    forwarding = false
    connected = false
    status = "USB forwarding stopped."
  }
  func chooseDestination() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose Export Folder"
    if panel.runModal() == .OK { destination = panel.url }
  }
  func exportSelected() {
    guard let app = selected, let destination, connected, !exporting && !busy else { return }
    exporting = true
    logs = []
    result = nil
    error = nil
    status = "Exporting \(app.name)…"
    let snapshot = profile
    Task {
      defer { exporting = false }
      do {
        result = try await client.export(app, profile: snapshot, destination: destination) {
          [weak self] line in
          Task { @MainActor in
            self?.logs.append(line)
            if (self?.logs.count ?? 0) > 1000 { self?.logs.removeFirst(100) }
          }
        }
        status =
          result?.fullyVerified == true
          ? "Native capture verified." : "Export finished with limitations."
      } catch {
        self.error = error.localizedDescription
        status = "Export did not complete. Review the error and retained run artifacts."
      }
    }
  }
  func cancel() {
    status = "Cancellation requested…"
    Task { await client.cancel() }
  }
  func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}
