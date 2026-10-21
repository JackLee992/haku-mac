import XCTest

@testable import HakuCore

final class HakuCoreTests: XCTestCase {
  func testActualApplicationSchema() throws {
    let apps = try JSONDecoder().decode(
      [DeviceApplication].self,
      from: Data(
        "[{\"bundle\":\"example.app\",\"name\":\"Example\",\"pid\":0,\"version\":\"1\"}]".utf8))
    XCTAssertEqual(apps.first?.identifier, "example.app")
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        [DeviceApplication].self,
        from: Data("[{\"identifier\":\"fake\",\"name\":\"Fake\",\"pid\":0}]".utf8)))
  }
  func testShellQuoteRoundtrip() async throws {
    let value = "a' $(touch /tmp/not-executed)\n; \" b"
    let result = try await HakuCore.run(
      "/bin/sh", ["-c", "printf %s " + shellQuote(value)], timeout: 5)
    XCTAssertEqual(result.status, 0)
    XCTAssertEqual(String(decoding: result.output, as: UTF8.self), value)
  }
  func testStrictSSHArguments() throws {
    var profile = ConnectionProfile()
    profile.sshPort = 2345
    profile.identityFile = "/tmp/key with space"
    profile.knownHostsFile = "/tmp/hosts with space"
    let args = try HakuClient().sshArguments(profile)
    XCTAssertTrue(args.contains("StrictHostKeyChecking=yes"))
    XCTAssertTrue(args.contains("BatchMode=yes"))
    XCTAssertTrue(args.contains("2345"))
    XCTAssertTrue(args.contains("/tmp/key with space"))
    XCTAssertTrue(args.contains("UserKnownHostsFile=\"/tmp/hosts with space\""))
    profile.remoteOutputRoot = "relative"
    XCTAssertThrowsError(try HakuClient().sshArguments(profile))
    profile.remoteOutputRoot = "/tmp/export"
    profile.host = "-oProxyCommand=evil"
    XCTAssertThrowsError(try HakuClient().sshArguments(profile))
  }
  func testProcessConcurrentPipes() async throws {
    let r = try await HakuCore.run(
      "/bin/sh",
      [
        "-c",
        "i=0; while [ $i -lt 10000 ]; do echo stdout; echo stderr >&2; i=$((i+1)); done; exit 7",
      ], timeout: 10)
    XCTAssertEqual(r.status, 7)
    XCTAssertEqual(r.output.count, 70000)
    XCTAssertEqual(r.error.count, 70000)
  }
  func testTimeout() async {
    do {
      _ = try await HakuCore.run("/bin/sleep", ["5"], timeout: 0.1)
      XCTFail("Expected timeout")
    } catch { XCTAssertTrue(error.localizedDescription.contains("timed out")) }
  }
  func testMockedConnectionRoundtripRequiresLiveList() async throws {
    let client = HakuClient { profile, command, timeout, progress in
      XCTAssertEqual(profile.serverPort, 57042)
      XCTAssertLessThanOrEqual(timeout, 45)
      if command.contains("--connection") {
        return CommandResult(
          status: 0, output: Data("{\"endpoint\":\"127.0.0.1:57042\"}".utf8), error: Data())
      }
      XCTAssertTrue(command.contains("--list"))
      return CommandResult(status: 1, output: Data(), error: Data("haku-server unavailable".utf8))
    }
    do {
      _ = try await client.checkConnection(ConnectionProfile())
      XCTFail("Endpoint metadata alone is not live health")
    } catch { XCTAssertTrue(error.localizedDescription.contains("haku-server unavailable")) }
  }
  func testZIPIntegrityRejectsTruncation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let member = directory.appendingPathComponent("member.txt")
    let archive = directory.appendingPathComponent("export.ipa")
    try Data("test payload".utf8).write(to: member)
    let created = try await HakuCore.run(
      "/usr/bin/zip", ["-j", archive.path, member.path], timeout: 5)
    XCTAssertEqual(created.status, 0)
    let verified = try await HakuCore.run("/usr/bin/unzip", ["-t", archive.path], timeout: 5)
    XCTAssertEqual(verified.status, 0)
    let data = try Data(contentsOf: archive)
    try data.prefix(data.count / 2).write(to: archive)
    let corrupt = try await HakuCore.run("/usr/bin/unzip", ["-t", archive.path], timeout: 5)
    XCTAssertNotEqual(corrupt.status, 0)
  }
  func testFailedExportRetainsReportAndNeverVerifies() async throws {
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: destination) }
    let client = HakuClient { _, command, _, progress in
      if command.hasPrefix("cat ") {
        return CommandResult(
          status: 0,
          output: Data(
            "{\"schema\":\"haku-capture-v1\",\"bundle\":\"example.app\",\"status\":\"failed\",\"error\":\"capture unavailable\",\"fully_verified\":true}"
              .utf8), error: Data())
      }
      XCTAssertTrue(command.contains("capture.pid"))
      XCTAssertTrue(command.contains("--dump"))
      progress?("capture unavailable")
      return CommandResult(status: 1, output: Data(), error: Data("capture unavailable".utf8))
    }
    let result = try await client.export(
      DeviceApplication(identifier: "example.app", name: "Example", pid: 0),
      profile: ConnectionProfile(), destination: destination
    ) { _ in }
    XCTAssertFalse(result.fullyVerified)
    XCTAssertFalse(result.sha256Verified)
    XCTAssertNil(result.ipaURL)
    XCTAssertEqual(result.status, "failed")
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.reportURL.path))
    XCTAssertTrue(result.summary.contains("Capture exited 1"))
  }
  func testOptionalReportByteCounts() throws {
    let report = try XCTUnwrap(
      JSONSerialization.jsonObject(
        with: Data(
          "{\"captured_bytes\":0,\"declared_encrypted_bytes\":2147483648,\"bundle_bytes\":-1,\"ipa_bytes\":true}"
            .utf8)) as? [String: Any])
    XCTAssertEqual(HakuClient.reportByteCount(report, "captured_bytes"), 0)
    XCTAssertEqual(HakuClient.reportByteCount(report, "declared_encrypted_bytes"), 2_147_483_648)
    XCTAssertNil(HakuClient.reportByteCount(report, "bundle_bytes"))
    XCTAssertNil(HakuClient.reportByteCount(report, "ipa_bytes"))
    XCTAssertNil(HakuClient.reportByteCount([:], "captured_bytes"))
  }
  func testCancellationStatusRequiresConfirmation() {
    for remote in ["capturing", "packaging"] {
      XCTAssertEqual(
        HakuClient.resultStatus(
          remoteStatus: remote, cancellationRequested: true,
          cancellationError: false, fullyVerified: false), "cancellation_unconfirmed")
    }
    XCTAssertEqual(
      HakuClient.resultStatus(
        remoteStatus: "cancelled", cancellationRequested: true,
        cancellationError: false, fullyVerified: false), "cancelled")
    XCTAssertEqual(
      HakuClient.resultStatus(
        remoteStatus: "verified", cancellationRequested: true,
        cancellationError: false, fullyVerified: false), "local_transfer_cancelled")
    XCTAssertEqual(
      HakuClient.resultStatus(
        remoteStatus: "cancelled", cancellationRequested: true,
        cancellationError: true, fullyVerified: false), "cancellation_unconfirmed")
  }
  func testReportSemantics() {
    var report: [String: Any] = [
      "schema": "haku-capture-v1", "status": "verified", "fully_verified": true,
      "main_verified": true, "zip_verified": true,
    ]
    XCTAssertTrue(HakuClient.reportAllowsFullVerification(report))
    report["status"] = "partial"
    XCTAssertFalse(HakuClient.reportAllowsFullVerification(report))
    report["status"] = "verified"
    report["cleanup_error"] = "still running"
    XCTAssertFalse(HakuClient.reportAllowsFullVerification(report))
  }
  func testStreamedSHA256() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("abc".utf8).write(to: url)
    XCTAssertEqual(
      try HakuClient.sha256(url), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
  }
}
