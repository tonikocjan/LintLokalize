import Foundation
import ArgumentParser
import Rainbow

public struct Main: ParsableCommand {
  @Argument
  var localizationFile: String
  
  @Option(help: "Available reporters: \(Reporters.allCases.map { $0.defaultValueDescription }).")
  var reporter: Reporters = .xcode
  
  @Option(help: "Pattern which follows a string literal to be matches.")
  var pattern: String = ".localized"
  
  @Option(help: "Should XCode display warnings or compile-time errors.")
  var severity: ViolationSeverity = .warning
  
  @Option(help: "Should the reporter output violations as they are found or must all the violations be collected before generating a report.")
  var realtime: Bool = false // @TODO: - Not yet used
  
  @Option(help: "Number of working threads.")
  var threads: Int = 1
  
  public init() {}
  
  public func run() throws {
    let reporter: Reporter = reporter.get()
    
    let (time1, contents) = try benchmark { () -> Set<String> in
      let fileManager = FileManager.default
      let workingDirectory = fileManager.currentDirectoryPath
//      let workingDirectory = "/Users/tony/swift/XcodeBenchmark"
      let contents = try loadContentsOfADirectory(
        path: workingDirectory,
        fileManager: fileManager)
      return contents
    }
    let (time2, mapping) = try benchmark {
      try loadLocalizationFile(path: localizationFile)
    }
    let (time3, errorCount) = try benchmark { () -> Int in
      let semaphore = DispatchSemaphore(value: 0)
      
      func work(
        startIndex: Set<String>.Index,
        count: Int
      ) throws -> Int {
        defer { semaphore.signal() }
        var errorCount = 0
        for index in 0..<count {
          let file = contents[contents.index(startIndex, offsetBy: index)]
          let violations = try parseAndValidateSourceCodeFile(
            file: file,
            localizations: mapping,
            pattern: pattern,
            severity: severity)
          print("Processing ", "\(file):".lightCyan)
          for violation in violations {
            print(reporter.report(violation: violation))
          }
          errorCount += violations.count
        }
        
        return errorCount
      }
      
      let workPerThread = contents.count / threads
      var results = [Result<Int, Error>?](repeating: nil, count: threads)
      for thread in 0..<threads {
        let count = thread == threads - 1 ? contents.count - workPerThread * thread : workPerThread
        let thread = Thread {
          do {
            let errorCount = try work(
              startIndex: contents.index(contents.startIndex, offsetBy: workPerThread * thread),
              count: count
            )
            results[thread] = .success(errorCount)
          } catch {
            results[thread] = .failure(error)
          }
        }
        thread.start()
      }
      
      for _ in 0..<threads { semaphore.wait() }
      
      var errorCount = 0
      for result in results {
        switch result! {
        case .success(let count):
          errorCount += count
        case .failure(let error):
          throw error
        }
      }
      return errorCount
    }
    if errorCount > 0 {
      print("❗️ Found \(errorCount) unresolved localizations!".bold.red)
    }
    print("Executed in: \(time1 + time2 + time3)s".lightBlue.italic)
    print(
      [
        "  - Load directory recursively: \(time1)s".cyan.italic,
        "  - Load localizaition file   : \(time2)s".cyan.italic,
        "  - Parse and validate sources: \(time3)s @ \(Double(contents.count) / time3) file/second".cyan.italic,
      ].joined(separator: "\n")
    )
  }
}

func loadContentsOfADirectory(
  path: String,
  recursive: Bool = true,
  fileExtensions: Set<String> = ["swift"],
  fileManager: FileManager
) throws -> Set<String> {
  var files = Set<String>()
  var visited = Set<String>()
  
  func work(path: String) throws {
    let contents = try fileManager.contentsOfDirectory(atPath: path)
    for name in contents {
      let wholePath = "\(path)/\(name)"
      
      guard !visited.contains(wholePath) else { continue }
      visited.insert(wholePath)
      
      var isDirectory: ObjCBool = false
      fileManager.fileExists(
        atPath: wholePath,
        isDirectory: &isDirectory)
      
      if isDirectory.boolValue {
        guard recursive else { continue }
        try work(path: wholePath)
      } else if fileExtensions.contains(URL(string: name)?.pathExtension ?? "") {
        files.insert(wholePath)
      }
    }
  }
  
  try work(path: path)
  return files
}

// @NOTE: - Could just return Set<Substring>,
// as values are not actually needed.
func loadLocalizationFile(
  path: String
) throws -> [String: String] {
  let contentsOfFile = try path.loadFile
  var mapping = [String: String]()
  var index = contentsOfFile.startIndex
  while index != contentsOfFile.endIndex {
    if contentsOfFile[index] == "\"" {
      var keyStartIndex: String.Index
      var keyEndIndex: String.Index
      index = contentsOfFile.index(after: index)
      keyStartIndex = index
      while contentsOfFile[index] != "\"" {
        index = contentsOfFile.index(after: index)
      }
      keyEndIndex = index
      index = contentsOfFile.index(after: index)
      
      while contentsOfFile[index] != "\"" {
        index = contentsOfFile.index(after: index)
      }
      
      var valueStartIndex: String.Index
      var valueEndIndex: String.Index
      index = contentsOfFile.index(after: index)
      valueStartIndex = index
      while contentsOfFile.endIndex != index && contentsOfFile[index] != "\"" {
        index = contentsOfFile.index(after: index)
      }
      valueEndIndex = index
      
      let key = contentsOfFile[keyStartIndex..<keyEndIndex]
      let value = contentsOfFile[valueStartIndex..<valueEndIndex]
      
      mapping[String(key)] = String(value)
      
      if index == contentsOfFile.endIndex { break }
      
      index = contentsOfFile.index(after: index)
      while contentsOfFile.endIndex != index && contentsOfFile[index] != "\"" {
        index = contentsOfFile.index(after: index)
      }
      index = contentsOfFile.index(before: index)
    } else {
      index = contentsOfFile.index(after: index)
    }
  }
  return mapping
}

struct Violation: Hashable {
  let file: String
  let line: Int
  let column: Int
  let key: String
  let severity: ViolationSeverity
}

func parseAndValidateSourceCodeFile(
  file: String,
  localizations: [String: String],
  pattern: String,
  severity: ViolationSeverity
) throws -> Set<Violation> {
  var violations = Set<Violation>()
  let code = try file.loadFile
  var index = code.startIndex
  var line = 1
  var column = 1
  
  func nextChar() {
    index = code.index(after: index)
    if index == code.endIndex { return }
    if code[index].isNewline {
      line = 1
      column += 1
    } else {
      line += 1
    }
  }
  
  while index != code.endIndex {
    if code[index] == "\"" {
      nextChar()
      let keyStartIndex: String.Index
      let keyEndIndex: String.Index
      keyStartIndex = index
      while index != code.endIndex && code[index] != "\"" {
        nextChar()
      }
      guard index != code.endIndex else { break }
      keyEndIndex = index
      let key = String(code[keyStartIndex..<keyEndIndex])
      nextChar()
      
      guard code[index...].count >= pattern.count else { break }
      guard code[index..<code.index(index, offsetBy: pattern.count)] == pattern else {
        nextChar()
        continue
      }
      guard localizations.keys.contains(key) else {
        violations.insert(.init(
          file: file,
          line: line,
          column: column,
          key: key,
          severity: severity))
        nextChar()
        continue
      }
    }
    nextChar()
  }
  return violations
}

protocol Reporter {
  func report(violation: Violation) -> String
}

struct XCodeReporter: Reporter {
  func report(violation: Violation) -> String {
    [
      "\(violation.file):",
      "\(violation.column):\(violation.line): ",
      "\(violation.severity.rawValue): ",
      "Unknown key: ",
      violation.key
    ].joined(separator: "")
  }
}

struct CommandLineReporter: Reporter {
  func report(violation: Violation) -> String {
    [
      "  ⚠️  ",
      "[\(violation.line),\(violation.column)] ",
      "\(violation.file): ",
      "Unknown key: \(violation.key)",
    ].joined(separator: "").red
  }
}

enum Reporters: String, ExpressibleByArgument, CaseIterable {
  case cmd
  case xcode
  
  func get() -> Reporter {
    switch self {
    case .cmd:
      return CommandLineReporter()
    case .xcode:
      return XCodeReporter()
    }
  }
}

enum ViolationSeverity: String, ExpressibleByArgument {
  case warning
  case error
}

public func benchmark(_ run: () throws -> Void) rethrows -> Double {
  let current = currentTime()
  try run()
  return currentTime() - current
}

public func benchmark<T>(_ run: () throws -> T) rethrows -> (time: Double, value: T) {
  let current = currentTime()
  let value = try run()
  return (currentTime() - current, value)
}

fileprivate func currentTime() -> Double {
#if os(macOS) || os(iOS)
  return CFAbsoluteTimeGetCurrent()
#else
  return Date().timeIntervalSinceNow
#endif
}

extension String {
  var loadFile: String {
    get throws {
      let data = try Data(contentsOf: .init(fileURLWithPath: self))
      return String(data: data, encoding: .utf8) ?? ""
    }
  }
}
