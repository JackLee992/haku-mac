import AppKit
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 16) {
        Group {
          if let url = ResourceBundle.current.url(
            forResource: "haku-chestnut", withExtension: "png"),
            let mascot = NSImage(contentsOf: url)
          {
            Image(nsImage: mascot).resizable().scaledToFit()
          } else {
            Image(systemName: "leaf.circle.fill").resizable().scaledToFit().foregroundStyle(
              Manga.yellow)
          }
        }.frame(width: 76, height: 76)
        VStack(alignment: .leading, spacing: 3) {
          Text("HAKU").font(.system(size: 31, weight: .black, design: .rounded)).tracking(3)
          Text("Your iPhone apps, carefully brought home.").font(.system(size: 13, weight: .medium))
        }
        Spacer()
        Text("栗  /  MAC EDITION").font(.system(size: 11, weight: .black, design: .monospaced))
          .tracking(1.5)
          .padding(12).background(Manga.yellow).rotationEffect(.degrees(-3))
      }.padding(.horizontal, 25).padding(.vertical, 13).background(Manga.paper)
      Rectangle().fill(Manga.ink).frame(height: 2)
      HSplitView {
        ConnectionSidebar(model: model).frame(minWidth: 240, idealWidth: 260, maxWidth: 300)
        ApplicationListView(model: model).frame(minWidth: 280, idealWidth: 340)
        ExportDetailView(model: model).frame(minWidth: 400, idealWidth: 520)
      }
      HStack(spacing: 8) {
        Circle().fill(model.connected ? Color.green : Manga.pink).frame(width: 7, height: 7)
        Text(model.status).lineLimit(2).font(.system(size: 11))
        Spacer()
        Text("DEVICE → MAC").font(.system(size: 10, weight: .bold, design: .monospaced))
      }.padding(.horizontal, 20).padding(.vertical, 11).background(Manga.paper)
    }.foregroundStyle(Manga.ink)
      .sheet(isPresented: $model.showConnection) { ConnectionEditor(model: model) }
  }
}
