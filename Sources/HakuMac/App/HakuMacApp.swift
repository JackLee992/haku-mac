import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var model: AppModel?
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if model?.exporting == true {
      let alert = NSAlert()
      alert.messageText = "An export is still running"
      alert.informativeText =
        "Keep Haku open to receive the result, or cancel the export in the main window before quitting."
      alert.addButton(withTitle: "Keep Haku Open")
      alert.runModal()
      return .terminateCancel
    }
    model?.stopForward()
    return .terminateNow
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
@main
struct HakuMacApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var model = AppModel()
  var body: some Scene {
    WindowGroup("Haku · Mac") {
      ContentView(model: model).frame(minWidth: 1080, minHeight: 740).preferredColorScheme(.light)
        .onAppear { delegate.model = model }
    }
    .defaultSize(width: 1280, height: 820)
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("Connection Settings…") { model.showConnection = true }.keyboardShortcut(",")
      }
      CommandMenu("Device") {
        Button("Connect / Refresh Apps") { model.connect() }.keyboardShortcut("r").disabled(
          model.busy || model.exporting)
        Button("Discover USB Devices") { model.discover() }.keyboardShortcut(
          "u", modifiers: [.command, .shift]
        ).disabled(model.busy || model.exporting)
        Divider()
        Button("Choose Export Folder…") { model.chooseDestination() }.keyboardShortcut(
          "o", modifiers: [.command, .shift]
        ).disabled(model.exporting)
        Button("Export Selected App") { model.exportSelected() }.keyboardShortcut("e").disabled(
          model.selected == nil || !model.connected || model.destination == nil || model.exporting
            || model.busy)
      }
    }
  }
}
