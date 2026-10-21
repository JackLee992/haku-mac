import CryptoKit
import Foundation

extension HakuClient {
  /// Missing legacy metrics remain unknown, and malformed or negative counts are rejected.
  static func reportByteCount(_ report: [String: Any], _ key: String) -> Int64? {
    guard let number = report[key] as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      let bytes = Int64(number.stringValue), bytes >= 0
    else { return nil }
    return bytes
  }

  static func resultStatus(
    remoteStatus: String, cancellationRequested: Bool,
    cancellationError: Bool, fullyVerified: Bool
  ) -> String {
    if cancellationRequested {
      if cancellationError || ["capturing", "packaging"].contains(remoteStatus) {
        return "cancellation_unconfirmed"
      }
      if remoteStatus == "cancelled" { return "cancelled" }
      if remoteStatus == "verified" { return "local_transfer_cancelled" }
      return remoteStatus
    }
    return remoteStatus == "verified" && !fullyVerified ? "local_verification_failed" : remoteStatus
  }

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
