import CryptoKit
import Foundation

extension HakuClient {
  static func reportAllowsFullVerification(_ report: [String: Any]) -> Bool {
    report["status"] as? String == "verified" && report["schema"] as? String == "haku-capture-v1"
      && report["fully_verified"] as? Bool == true && report["main_verified"] as? Bool == true
      && report["zip_verified"] as? Bool == true && report["cleanup_error"] == nil
      && report["error"] == nil
  }
  public static func sha256(_ url: URL) throws -> String {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    var hash = SHA256()
    while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty {
      hash.update(data: data)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
