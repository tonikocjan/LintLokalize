import Foundation
import ArgumentParser
import Rainbow

public struct Main: ParsableCommand {
  @Argument
  var localizationFile: String
  
  public init() {}
  
  public func run() throws {
    let (time1, contents) = try benchmark { () -> Set<String> in
      let fileManager = FileManager.default
      let workingDirectory = "/Users/tony/ios/facelift-ios/Facelift"
      let contents = try loadContentsOfADirectory(
        path: workingDirectory,
        fileManager: fileManager)
      return contents
    }
    let (time2, mapping) = try benchmark {
      try loadLocalizationFile(path: localizationFile)
    }
    let (time3, errorCount) = try benchmark { () -> Int in
      var errorCount = 0
      for (index, file) in contents.enumerated() {
        let unknownKeys = try parseAndValidateSourceCodeFile(
          file: file,
          localizations: mapping)
        print("\(index + 1). Processing: ", file.lightCyan)
        for key in unknownKeys {
          print("  -".red, key.red)
        }
        errorCount += unknownKeys.count
      }
      return errorCount
    }
    if errorCount > 0 {
      print("❗️ Found \(errorCount) unresolved localizations!".bold.red)
    }
    print("Executed in: \(time1 + time2 + time3)".magenta.italic)
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

func parseAndValidateSourceCodeFile(
  file: String,
  localizations: [String: String]
) throws -> Set<String> {
  var keys = Set<String>()
  let code = try file.loadFile
  var index = code.startIndex
  while index != code.endIndex {
    if code[index] == "\"" {
      index = code.index(after: index)
      let keyStartIndex: String.Index
      let keyEndIndex: String.Index
      keyStartIndex = index
      while index != code.endIndex && code[index] != "\"" {
        index = code.index(after: index)
      }
      guard index != code.endIndex else { break }
      keyEndIndex = index
      let key = String(code[keyStartIndex..<keyEndIndex])
      index = code.index(after: index)
      let pattern = ".localized("
      guard code[index...].count >= pattern.count else { break }
      guard code[index..<code.index(index, offsetBy: pattern.count)] == pattern else {
        index = code.index(index, offsetBy: pattern.count)
        continue
      }
      guard localizations.keys.contains(key) else {
        keys.insert(key)
        index = code.index(after: index)
        continue
      }
    }
    index = code.index(after: index)
  }
  return keys
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
