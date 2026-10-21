import SwiftUI

struct ConnectionSidebar: View {
  @ObservedObject var model: AppModel
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("01  CONNECT").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
        VStack(alignment: .leading, spacing: 10) {
          Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(
            .system(size: 34, weight: .light))
          Text(model.profile.name).font(.system(size: 21, weight: .bold, design: .rounded))
          Text("\(model.profile.username)@\(model.profile.host):\(String(model.profile.sshPort))")
            .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
          Text(model.connected ? "Connection checked" : "Not connected").font(.caption)
            .foregroundStyle(.secondary)
          Button("Edit Connection…") { model.showConnection = true }.buttonStyle(.link)
          Button {
            model.connect()
          } label: {
            Label(model.connected ? "Refresh Apps" : "Connect", systemImage: "bolt.fill").frame(
              maxWidth: .infinity)
          }
          .buttonStyle(MangaButtonStyle()).disabled(model.busy || model.exporting)
        }
        Divider()
        VStack(alignment: .leading, spacing: 12) {
          Label("USB SHORTCUT", systemImage: "cable.connector").font(
            .system(size: 11, weight: .black))
          Text("Forward your device’s SSH port over USB. Requires iproxy on this Mac.").font(
            .caption
          ).foregroundStyle(.secondary)
          Button("Find USB Devices") { model.discover() }.disabled(model.busy || model.exporting)
          if !model.devices.isEmpty {
            Picker("Device", selection: $model.deviceID) {
              ForEach(model.devices) { device in Text(device.name).tag(Optional(device.id)) }
            }.labelsHidden()
            Button(model.forwarding ? "Restart Forwarding" : "Start Forwarding") { model.forward() }
              .disabled(model.busy || model.exporting)
          }
          if model.forwarding {
            Button("Stop Forwarding") { model.stopForward() }.disabled(model.exporting)
          }
        }
        Spacer(minLength: 10)
        VStack(alignment: .leading, spacing: 8) {
          Text("A LITTLE PREPARATION").font(.system(size: 10, weight: .black)).tracking(1)
          Text(
            "Haku must already be installed on your supported device. Set up SSH key or agent access and trust the device’s host key first."
          ).font(.caption).lineSpacing(4)
          Text("No passwords or private key contents are stored.").font(.caption2).foregroundStyle(
            .secondary)
        }.padding(14).background(Manga.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
      }.padding(22)
    }.background(Manga.paper)
  }
}
