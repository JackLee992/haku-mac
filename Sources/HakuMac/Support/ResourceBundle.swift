import Foundation

/// SwiftPM resources live in Contents/Resources in the signed app bundle.
enum ResourceBundle {
  static let current: Bundle = {
    if let url = Bundle.main.resourceURL?.appendingPathComponent("HakuMac_HakuMac.bundle"),
      let bundle = Bundle(url: url)
    {
      return bundle
    }
    return Bundle.module
  }()
}
