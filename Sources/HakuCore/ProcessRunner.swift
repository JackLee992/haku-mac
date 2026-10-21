import Foundation

/// A single-quote shell word; remote SSH commands always pass through this boundary.
public func shellQuote(_ value: String) -> String {
  "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
struct CommandResult {
  let status: Int32
  let output: Data
  let error: Data
}
final class Collector: @unchecked Sendable {
  let lock = NSLock()
  var data = Data()
  func append(_ d: Data) {
    lock.lock()
    data.append(d)
    lock.unlock()
  }
}
/// Both pipes are drained concurrently, including after timeout. No shell is used locally.
func run(
  _ executable: String, _ arguments: [String], timeout: TimeInterval,
  progress: (@Sendable (String) -> Void)? = nil
) async throws -> CommandResult {
  try await Task.detached {
    try runBlocking(executable, arguments, timeout: timeout, progress: progress)
  }.value
}
private func runBlocking(
  _ executable: String, _ arguments: [String], timeout: TimeInterval,
  progress: (@Sendable (String) -> Void)?
) throws -> CommandResult {
  let process = Process()
  let out = Pipe()
  let err = Pipe()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.standardOutput = out
  process.standardError = err
  let stdout = Collector()
  let stderr = Collector()
  let group = DispatchGroup()
  try process.run()
  for (pipe, collector, isError) in [(out, stdout, false), (err, stderr, true)] {
    group.enter()
    DispatchQueue.global().async {
      while true {
        let data = pipe.fileHandleForReading.availableData
        if data.isEmpty { break }
        collector.append(data)
        if isError { progress?(String(decoding: data, as: UTF8.self)) }
      }
      group.leave()
    }
  }
  let deadline = Date().addingTimeInterval(timeout)
  while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
  let timedOut = process.isRunning
  if timedOut {
    process.terminate()
    Thread.sleep(forTimeInterval: 0.3)
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
  }
  process.waitUntilExit()
  if group.wait(timeout: .now() + 2) == .timedOut {
    try? out.fileHandleForReading.close()
    try? err.fileHandleForReading.close()
    throw HakuError("Command pipe drain timed out")
  }
  if timedOut { throw HakuError("Command timed out after \(Int(timeout)) seconds: \(executable)") }
  return CommandResult(status: process.terminationStatus, output: stdout.data, error: stderr.data)
}
