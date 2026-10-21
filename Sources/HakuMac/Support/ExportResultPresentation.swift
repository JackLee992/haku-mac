import HakuCore

extension ExportResult {
  var captureHeading: String {
    if fullyVerified { return "Native capture verified" }
    switch status.lowercased() {
    case "cancellation_unconfirmed": return "Cancellation unconfirmed"
    case "local_transfer_cancelled": return "Local retrieval cancelled"
    case "cancelled", "canceled": return "Export cancelled"
    case "failed", "error": return "Capture failed"
    case "local_verification_failed": return "Local artifact verification failed"
    default: return "Partial / unverified capture"
    }
  }
  var captureStatusMessage: String {
    if fullyVerified { return "Native capture verified." }
    switch status.lowercased() {
    case "cancellation_unconfirmed":
      return "Cancellation unconfirmed; remote capture may still be running. Inspect the report."
    case "local_transfer_cancelled":
      return "Remote capture completed; local retrieval was cancelled. Inspect retained evidence."
    case "cancelled", "canceled": return "Export cancelled; retained evidence is available."
    case "failed", "error": return "Capture failed; inspect the report."
    case "local_verification_failed":
      return "Local artifact verification failed; inspect the report."
    default: return "Partial capture; inspect the report."
    }
  }
}
