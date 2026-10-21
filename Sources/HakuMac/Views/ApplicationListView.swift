import SwiftUI

struct ApplicationListView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("02  PICK AN APP").font(.system(size: 11, weight: .black, design: .monospaced))
          .tracking(2)
        Spacer()
        Text("\(model.applications.count)").font(.caption.monospaced()).padding(6).background(
          Manga.yellow, in: Circle())
      }.padding(20)
      HStack {
        Image(systemName: "magnifyingglass")
        TextField("Search name or bundle ID", text: $model.search).textFieldStyle(.plain)
      }.padding(10).background(Manga.paper, in: RoundedRectangle(cornerRadius: 9)).padding(
        .horizontal, 16
      ).padding(.bottom, 12)
      if model.busy {
        ProgressView().controlSize(.small).padding(.horizontal, 20).padding(.bottom, 10)
      }
      if model.applications.isEmpty {
        ContentUnavailableView(
          model.connected ? "No apps returned" : "Your library starts here",
          systemImage: "square.stack.3d.up",
          description: Text(
            model.connected
              ? "Refresh to request the current device app list."
              : "Connect your device to load its real app list.")
        ).frame(maxHeight: .infinity)
      } else {
        List(selection: $model.selectedID) {
          ForEach(model.filtered) { app in
            HStack(spacing: 12) {
              Image(systemName: "app.dashed").font(.system(size: 24)).foregroundStyle(
                Manga.ink.opacity(0.65))
              VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.system(size: 13, weight: .semibold))
                Text(app.identifier).font(.system(size: 10, design: .monospaced)).foregroundStyle(
                  .secondary
                ).lineLimit(1)
              }
            }.padding(.vertical, 7).tag(app.id)
          }
        }.listStyle(.inset).disabled(model.exporting)
        if model.filtered.isEmpty { Text("No matching apps.").font(.caption).padding(20) }
      }
    }.background(.white)
  }
}
