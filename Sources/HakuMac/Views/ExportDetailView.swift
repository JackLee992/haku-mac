import SwiftUI

struct ExportDetailView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("03  BRING IT HOME").font(.system(size: 11, weight: .black, design: .monospaced))
          .tracking(2)
        if let app = model.selected {
          VStack(alignment: .leading, spacing: 10) {
            Text(app.name).font(.system(size: 31, weight: .black, design: .rounded))
            Text(app.identifier).font(.system(size: 11, design: .monospaced)).foregroundStyle(
              .secondary
            ).textSelection(.enabled)
            Label(
              app.pid > 0 ? "Running · PID \(app.pid)" : "Not currently running",
              systemImage: "circle.dotted"
            ).font(.caption)
          }
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("A new home\nfor your apps.").font(
              .system(size: 32, weight: .black, design: .rounded))
            Text("Select an app from the device library to begin.").font(.callout).foregroundStyle(
              .secondary)
          }
        }
        MangaCard(color: Manga.yellow.opacity(0.30)) {
          VStack(alignment: .leading, spacing: 14) {
            Label("EXPORT DESTINATION", systemImage: "folder").font(
              .system(size: 11, weight: .black)
            ).tracking(1)
            Text(model.destination?.path ?? "Choose a folder on your Mac.").font(
              .system(size: 12, design: .monospaced)
            ).lineLimit(3).textSelection(.enabled)
            Button("Choose Folder…") { model.chooseDestination() }.disabled(model.exporting)
            Divider()
            Button {
              model.exportSelected()
            } label: {
              Label("Export App", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity)
            }.buttonStyle(MangaButtonStyle()).disabled(
              model.selected == nil || !model.connected || model.destination == nil
                || model.exporting || model.busy)
            Text(
              "Each run gets its own folder. Haku checks the report, SHA-256 and ZIP before declaring a verified export."
            ).font(.caption).foregroundStyle(.secondary).lineSpacing(3)
          }
        }
        if model.exporting {
          HStack {
            ProgressView().controlSize(.small)
            Text("Working on your device…").font(.callout)
            Spacer()
            Button("Cancel") { model.cancel() }
          }
        }
        if let error = model.error {
          MangaCard(color: Manga.pink.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 10) {
              Label("Needs attention", systemImage: "exclamationmark.bubble").font(.headline)
              Text(error).font(.system(size: 12)).textSelection(.enabled)
              if let destination = model.destination {
                Button("Open Export Folder") { model.reveal(destination) }
              }
            }
          }
        }
        if let result = model.result {
          MangaCard(
            color: result.fullyVerified ? Manga.yellow.opacity(0.45) : Manga.pink.opacity(0.35)
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Label(
                result.captureHeading,
                systemImage: result.fullyVerified ? "checkmark.seal" : "exclamationmark.triangle"
              ).font(.headline)
              Text("Status: \(result.status)").font(.caption.monospaced())
              Text(result.summary).font(.callout).textSelection(.enabled)
              if result.capturedBytes != nil || result.declaredEncryptedBytes != nil
                || result.bundleBytes != nil || result.ipaBytes != nil
              {
                VStack(spacing: 7) {
                  byteRow("Captured encrypted bytes", value: result.capturedBytes, exact: true)
                  byteRow(
                    "Declared encrypted bytes", value: result.declaredEncryptedBytes, exact: true)
                  byteRow("App bundle", value: result.bundleBytes)
                  byteRow("IPA archive", value: result.ipaBytes)
                }.padding(.vertical, 6)
              }
              Text(
                "Signing, installation, ordinary launch, and app functionality are not verified by this export."
              ).font(.caption).foregroundStyle(.secondary)
              HStack {
                verification("SHA-256", passed: result.sha256Verified)
                verification("ZIP", passed: result.zipVerified)
              }
              Button("Reveal Run Artifacts") { model.reveal(result.directory) }
              Button("Open Report") { model.reveal(result.reportURL) }
              if let ipa = result.ipaURL { Button("Reveal IPA") { model.reveal(ipa) } }
            }
          }
        }
        if !model.logs.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("FIELD NOTES / LIVE LOG").font(
              .system(size: 10, weight: .black, design: .monospaced)
            ).tracking(1)
            ScrollView {
              Text(model.logs.joined(separator: "\n")).font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(12)
            }.frame(height: 180).background(
              Manga.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
          }
        }
      }.padding(26)
    }.background(Manga.paper)
  }
  @ViewBuilder
  private func byteRow(_ label: String, value: Int64?, exact: Bool = false) -> some View {
    if let value, value >= 0 {
      HStack(alignment: .firstTextBaseline) {
        Text(label).foregroundStyle(.secondary)
        Spacer(minLength: 12)
        Text(byteDescription(value, exact: exact)).multilineTextAlignment(.trailing).textSelection(
          .enabled)
      }.font(.caption)
    }
  }
  private func byteDescription(_ value: Int64, exact: Bool) -> String {
    let formatted = ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    return exact ? "\(formatted) (\(String(value)) bytes)" : formatted
  }
  private func verification(_ title: String, passed: Bool) -> some View {
    Label(
      passed ? "\(title) verified" : "\(title) unverified",
      systemImage: passed ? "checkmark.circle" : "minus.circle"
    ).font(.caption)
  }
}
