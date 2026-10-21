import Foundation

public final class HakuClient: @unchecked Sendable {
  private let lock = NSLock()
  private var active: (ConnectionProfile, String)?
  private var forwarding: Process?
  private var cancelled = false
  private var downloadProcess: Process?
  private var captureFinished = false
  private var progressHandler: (@Sendable (String) -> Void)?
  private var transport:
    (
      @Sendable (ConnectionProfile, String, TimeInterval, (@Sendable (String) -> Void)?)
        async throws -> CommandResult
    )?
  public init() {}
  init(
    transport:
      @escaping @Sendable (ConnectionProfile, String, TimeInterval, (@Sendable (String) -> Void)?)
      async throws -> CommandResult
  ) { self.transport = transport }
  func sshArguments(_ p: ConnectionProfile) throws -> [String] {
    for value in [
      p.host, p.username, p.identityFile, p.knownHostsFile, p.hakuPath, p.remoteOutputRoot,
    ] {
      guard !value.contains("\0"), !value.contains("\n"), !value.contains("\r") else {
        throw HakuError("Connection fields cannot contain control characters")
      }
    }
    guard p.hakuPath.hasPrefix("/"), p.remoteOutputRoot.hasPrefix("/"), p.remoteOutputRoot != "/"
    else {
      throw HakuError(
        "Haku and remote output paths must be absolute; output cannot be filesystem root")
    }
    let knownHosts = (p.knownHostsFile as NSString).expandingTildeInPath.replacingOccurrences(
      of: "\\", with: "\\\\"
    ).replacingOccurrences(of: "\"", with: "\\\"")
    guard (1...65535).contains(p.sshPort), (1...65535).contains(p.serverPort), !p.host.isEmpty,
      !p.username.isEmpty, !p.host.hasPrefix("-"), !p.username.hasPrefix("-")
    else { throw HakuError("Invalid host, user or port") }
    var args = [
      "-T", "-p", String(p.sshPort), "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o",
      "UserKnownHostsFile=\"" + knownHosts + "\"", "-o", "ConnectTimeout=10", "-o",
      "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3",
    ]
    if !p.identityFile.isEmpty {
      args += ["-i", (p.identityFile as NSString).expandingTildeInPath]
    }
    args += ["-l", p.username, "--", p.host]
    return args
  }
  func ssh(
    _ p: ConnectionProfile, _ command: String, timeout: TimeInterval = 45,
    progress: (@Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    if let transport { return try await transport(p, command, timeout, progress) }
    return try await run(
      "/usr/bin/ssh", try sshArguments(p) + [command], timeout: timeout, progress: progress)
  }
  func checked(_ r: CommandResult) throws -> Data {
    guard r.status == 0 else {
      throw HakuError(
        "Remote command failed (\(r.status)): \(String(decoding:r.error,as:UTF8.self))")
    }
    return r.output
  }
  func command(_ p: ConnectionProfile, _ args: [String]) -> String {
    ([p.hakuPath, "--port", String(p.serverPort)] + args).map(shellQuote).joined(separator: " ")
  }
  public func applications(_ profile: ConnectionProfile) async throws -> [DeviceApplication] {
    try JSONDecoder().decode(
      [DeviceApplication].self, from: checked(await ssh(profile, command(profile, ["--list"]))))
  }
  public func checkConnection(_ profile: ConnectionProfile) async throws -> String {
    let data = try checked(await ssh(profile, command(profile, ["--connection"])))
    let apps = try await applications(profile)
    let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let endpoint = metadata?["endpoint"] as? String, !endpoint.isEmpty else {
      throw HakuError("Haku returned invalid connection metadata")
    }
    return "Connected · \(apps.count) apps · Haku \(endpoint)"
  }
  private func setActive(_ value: (ConnectionProfile, String)?) {
    lock.lock()
    active = value
    if value == nil { progressHandler = nil }
    lock.unlock()
  }
  private func getActive() -> (ConnectionProfile, String)? {
    lock.lock()
    defer { lock.unlock() }
    return active
  }
  private func markCancelled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    cancelled = true
    downloadProcess?.terminate()
    return captureFinished
  }
  private func finishCapture() {
    lock.lock()
    captureFinished = true
    lock.unlock()
  }
  private func isCancelled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
  private func begin(
    _ p: ConnectionProfile, _ control: String, _ local: URL,
    _ progress: @escaping @Sendable (String) -> Void
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard active == nil else { throw HakuError("An export is already running") }
    cancelled = false
    captureFinished = false
    cancellationErrorPath = local.appendingPathComponent("cancellation-error.txt").path
    active = (p, control)
    progressHandler = progress
  }
  public func cancel() async {
    if markCancelled() {
      emit("Local transfer cancellation requested")
      return
    }
    guard let (p, path) = getActive() else { return }
    do {
      let q = shellQuote(path)
      _ = try checked(
        await ssh(
          p,
          "i=0; while [ ! -f \(q)/capture.pid ] && [ $i -lt 20 ]; do sleep 0.2; i=$((i+1)); done; test -f \(q)/capture.pid && p=$(cat \(q)/capture.pid) && case \"$p\" in ''|*[!0-9]*) exit 2;; esac && kill -INT \"$p\"",
          timeout: 20))
    } catch {
      let message = "Cancellation could not be confirmed: \(error.localizedDescription)"
      emit(message)
      try? message.write(toFile: pathForCancellationError(), atomically: true, encoding: .utf8)
    }
  }
  private func emit(_ text: String) {
    lock.lock()
    let handler = progressHandler
    lock.unlock()
    handler?(text)
  }
  private var cancellationErrorPath: String = ""
  private func pathForCancellationError() -> String {
    lock.lock()
    defer { lock.unlock() }
    return cancellationErrorPath
  }
  public func export(
    _ app: DeviceApplication, profile p: ConnectionProfile, destination: URL,
    progress: @escaping @Sendable (String) -> Void
  ) async throws -> ExportResult {
    guard getActive() == nil else { throw HakuError("An export is already running") }
    let token = UUID().uuidString
    let local = destination.appendingPathComponent("Haku-" + token)
    let remote = p.remoteOutputRoot + "/" + token
    let control = p.remoteOutputRoot + "/.control-" + token
    try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
    try begin(p, control, local, progress)
    defer { setActive(nil) }
    let capture = command(p, ["--dump", app.identifier, remote])
    let script =
      "umask 077; mkdir -p \(shellQuote(p.remoteOutputRoot)) && mkdir \(shellQuote(control)) || exit 1; \(capture) & child=$!; echo \"$child\" > \(shellQuote(control))/capture.pid; wait \"$child\"; result=$?; rm -f \(shellQuote(control))/capture.pid; rmdir \(shellQuote(control)); exit \"$result\""
    var captureFailure: Error?
    do {
      let r = try await ssh(p, script, timeout: 1800, progress: progress)
      try r.output.write(to: local.appendingPathComponent("stdout.json"))
      try r.error.write(to: local.appendingPathComponent("stderr.log"))
      if r.status != 0 { captureFailure = HakuError("Capture exited \(r.status)") }
    } catch {
      captureFailure = error
      await cancel()
    }
    finishCapture()
    let reportURL = local.appendingPathComponent("report.json")
    do {
      let deadline = Date().addingTimeInterval(20)
      while true {
        let data = try checked(
          await ssh(p, "cat \(shellQuote(remote+"/report.json"))", timeout: 30))
        try data.write(to: reportURL)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if !["capturing", "packaging"].contains(object?["status"] as? String ?? "")
          || Date() > deadline
        {
          break
        }
        try await Task.sleep(nanoseconds: 500_000_000)
      }
    } catch {
      try? String(describing: captureFailure ?? error).write(
        to: local.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
      throw HakuError(
        "Report retrieval failed. Artifacts retained at \(local.path): \(error.localizedDescription)"
      )
    }
    guard
      let report = try JSONSerialization.jsonObject(with: Data(contentsOf: reportURL))
        as? [String: Any], report["schema"] as? String == "haku-capture-v1",
      report["bundle"] as? String == app.identifier
    else { throw HakuError("Report identity/schema mismatch; retained at \(local.path)") }
    let status = report["status"] as? String ?? "unknown"
    var ipa: URL?
    var sha = false
    var zip = false
    if !isCancelled(), report["ipa"] as? String == "export.ipa" {
      progress("Downloading IPA…")
      // SSH streams archive stdout directly to a local file, avoiding in-memory archive buffering.
      let target = local.appendingPathComponent("export.ipa")
      var downloaded = false
      do {
        try await download(p, remote: remote + "/export.ipa", to: target)
        downloaded = true
      } catch {
        try? error.localizedDescription.write(
          to: local.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
        if isCancelled() {
          captureFailure = error
        } else {
          throw HakuError(
            "IPA download failed. Report and partial archive retained at \(local.path): \(error.localizedDescription)"
          )
        }
      }
      if downloaded {
        ipa = target
        sha = try Self.sha256(target) == (report["ipa_sha256"] as? String ?? "").lowercased()
        let test = try await run("/usr/bin/unzip", ["-t", target.path], timeout: 300)
        zip = test.status == 0
        try test.output.write(to: local.appendingPathComponent("zip-verification.txt"))
      }
    }
    let cancelError = try? String(contentsOfFile: pathForCancellationError(), encoding: .utf8)
    let full =
      !isCancelled() && captureFailure == nil && cancelError == nil
      && Self.reportAllowsFullVerification(report) && sha && zip
    let summary =
      full
      ? "Export and local SHA256/ZIP verified"
      : "Remote status: \(status) · fully verified: no · SHA256: \(sha) · ZIP: \(zip)"
        + (captureFailure.map { " · \($0.localizedDescription)" } ?? "")
        + (cancelError.map { " · \($0)" } ?? "")
        + (isCancelled() ? " · cancellation requested" : "")
    try summary.write(
      to: local.appendingPathComponent("verification.txt"), atomically: true, encoding: .utf8)
    let localStatus = Self.resultStatus(
      remoteStatus: status, cancellationRequested: isCancelled(),
      cancellationError: cancelError != nil, fullyVerified: full)
    return ExportResult(
      directory: local, reportURL: reportURL, ipaURL: ipa, status: localStatus, fullyVerified: full,
      sha256Verified: sha, zipVerified: zip, summary: summary,
      capturedBytes: Self.reportByteCount(report, "captured_bytes"),
      declaredEncryptedBytes: Self.reportByteCount(report, "declared_encrypted_bytes"),
      bundleBytes: Self.reportByteCount(report, "bundle_bytes"),
      ipaBytes: Self.reportByteCount(report, "ipa_bytes"))
  }
  private func download(_ p: ConnectionProfile, remote: String, to target: URL) async throws {
    let args = try sshArguments(p) + ["cat " + shellQuote(remote)]
    try await Task.detached { try self.downloadBlocking(args, to: target) }.value
  }
  private func downloadBlocking(_ args: [String], to target: URL) throws {
    _ = FileManager.default.createFile(atPath: target.path, contents: nil)
    let handle = try FileHandle(forWritingTo: target)
    defer { try? handle.close() }
    let process = Process()
    let errors = Pipe()
    let collector = Collector()
    let group = DispatchGroup()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    process.arguments = args
    process.standardOutput = handle
    process.standardError = errors
    try process.run()
    lock.lock()
    downloadProcess = process
    let stop = cancelled
    lock.unlock()
    defer {
      lock.lock()
      downloadProcess = nil
      lock.unlock()
    }
    if stop { process.terminate() }
    group.enter()
    DispatchQueue.global().async {
      collector.append(errors.fileHandleForReading.readDataToEndOfFile())
      group.leave()
    }
    let deadline = Date().addingTimeInterval(1800)
    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
    if process.isRunning {
      process.terminate()
      Thread.sleep(forTimeInterval: 0.3)
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
    process.waitUntilExit()
    guard group.wait(timeout: .now() + 2) == .success else {
      throw HakuError("Download pipe drain timed out")
    }
    guard process.terminationStatus == 0 else {
      throw HakuError("IPA download failed: " + String(decoding: collector.data, as: UTF8.self))
    }
  }
  func tool(_ name: String) throws -> String {
    for root in ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/"] {
      if FileManager.default.isExecutableFile(atPath: root + name) { return root + name }
    }
    throw HakuError("Install libimobiledevice/usbmuxd tools: missing \(name)")
  }
  public func discoverUSBDevices() async throws -> [USBDevice] {
    let r = try checked(await run(tool("idevice_id"), ["-l"], timeout: 15))
    return String(decoding: r, as: UTF8.self).split(whereSeparator: { $0.isNewline }).map {
      USBDevice(id: String($0), name: "iPhone · \($0.prefix(8))")
    }
  }
  public func startUSBForward(device: USBDevice, localPort: Int, remotePort: Int) async throws {
    guard (1...65535).contains(localPort), (1...65535).contains(remotePort) else {
      throw HakuError("Invalid forwarding port")
    }
    stopUSBForward()
    let p = Process()
    p.executableURL = URL(fileURLWithPath: try tool("iproxy"))
    p.arguments = ["-u", device.id, "\(localPort):\(remotePort)"]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try p.run()
    try await Task.sleep(nanoseconds: 300_000_000)
    guard p.isRunning else { throw HakuError("iproxy exited; check device and local port") }
    forwarding = p
  }
  public func stopUSBForward() {
    forwarding?.terminate()
    forwarding = nil
  }
}
