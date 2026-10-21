import SwiftUI

enum Manga {
  static let ink = Color(red: 0.18, green: 0.15, blue: 0.20)
  static let paper = Color(red: 1, green: 0.97, blue: 0.89)
  static let yellow = Color(red: 1, green: 0.82, blue: 0.26)
  static let pink = Color(red: 1, green: 0.73, blue: 0.77)
}
struct MangaCard<Content: View>: View {
  var color: Color = .white
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 16).fill(color)
          .shadow(color: Manga.ink.opacity(0.14), radius: 0, x: 3, y: 4)
      }
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Manga.ink, lineWidth: 1.5))
  }
}
struct MangaButtonStyle: ButtonStyle {
  var color: Color = Manga.yellow
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .bold)).padding(.horizontal, 15).padding(
      .vertical, 10
    )
    .foregroundStyle(Manga.ink).background(color, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Manga.ink, lineWidth: 1.5))
    .offset(y: configuration.isPressed ? 2 : 0)
  }
}
