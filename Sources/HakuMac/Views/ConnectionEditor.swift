import SwiftUI

struct ConnectionEditor: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Make a connection.").font(.system(size: 28, weight: .black, design: .rounded))
      Text("SSH key or agent authentication • strict host-key verification").font(.caption)
        .foregroundStyle(.secondary)
      Form {
        Section("Device") {
          TextField("Profile name", text: $model.profile.name)
          TextField("SSH host", text: $model.profile.host)
          TextField("SSH port", value: $model.profile.sshPort, format: .number.grouping(.never))
          TextField("SSH user", text: $model.profile.username)
        }
        Section("Authentication paths") {
          TextField("Private key path (optional)", text: $model.profile.identityFile)
          TextField("Known hosts file", text: $model.profile.knownHostsFile)
          Text("Only file paths are saved. Leave the key path empty to use your SSH agent.").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        Section("Remote Haku engine") {
          TextField("Haku executable", text: $model.profile.hakuPath)
          TextField(
            "Server port", value: $model.profile.serverPort, format: .number.grouping(.never))
          TextField("Remote output folder", text: $model.profile.remoteOutputRoot)
        }
      }.formStyle(.grouped)
      HStack {
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(MangaButtonStyle()).keyboardShortcut(
          .defaultAction)
      }
    }.padding(24).frame(width: 600, height: 670).background(Manga.paper).disabled(
      model.exporting || model.busy)
  }
}
