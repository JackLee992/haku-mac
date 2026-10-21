import Foundation

public struct ConnectionProfile: Codable, Equatable, Sendable {
  public var name = "My iPhone", host = "127.0.0.1", sshPort = 2222, username = "mobile",
    identityFile = "", knownHostsFile = "~/.ssh/known_hosts", serverPort = 57042,
    hakuPath = "/var/jb/Applications/Haku.app/Haku", remoteOutputRoot = "/var/mobile/Media/HakuMac"
  public init() {}
}
public struct DeviceApplication: Codable, Identifiable, Hashable, Sendable {
  public let identifier: String
  public let name: String
  public let pid: Int
  public var id: String { identifier }
  enum CodingKeys: String, CodingKey {
    case identifier = "bundle"
    case name, pid
  }
  public init(identifier: String, name: String, pid: Int) {
    self.identifier = identifier
    self.name = name
    self.pid = pid
  }
}
public struct USBDevice: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}
public struct ExportResult: Sendable {
  public let directory: URL, reportURL: URL
  public let ipaURL: URL?
  public let status: String
  public let fullyVerified: Bool, sha256Verified: Bool, zipVerified: Bool
  public let summary: String
  public let capturedBytes: Int64?
  public let declaredEncryptedBytes: Int64?
  public let bundleBytes: Int64?
  public let ipaBytes: Int64?
}
public struct HakuError: LocalizedError {
  public let message: String
  public var errorDescription: String? { message }
  public init(_ message: String) { self.message = message }
}
