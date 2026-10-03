import ArgumentParser

struct ListError: Error, CustomStringConvertible {
  let description: String
}

enum ANSIColor: String {
  case reset = "\u{001B}[0m"
  case red = "\u{001B}[31m"
  case purple = "\u{001B}[35m"
  case blue = "\u{001B}[34m"
  case cyan = "\u{001B}[36m"
  case white = "\u{001B}[37m"
  case grey = "\u{001B}[90m"
  case none = ""
}

enum EntryType {
  case unknown
  case fifo
  case character
  case directory
  case block
  case regular
  case symlink
  case socket
}

struct Entry {
  let name: String
  let type: EntryType
  var sortKey: String
  var symlinkDest: String?
  var executable: Bool

  init(name: String, type: EntryType, symlinkDest: String?, executable: Bool) {
    self.name = name
    self.type = type
    self.symlinkDest = symlinkDest
    self.executable = executable

    sortKey = name.lowercased()
    if name.hasPrefix(".") {
      sortKey.removeFirst()
    }
  }

  func formatted(useColor: Bool) -> String {
    let leading =
      name.hasPrefix(".")
      ? ""
      : " "
    let trailing =
      type == .symlink && symlinkDest != nil
      ? " -> \(symlinkDest ?? "")"
      : ""

    if useColor {
      var color: ANSIColor
      switch type {
      case .symlink:
        color = .purple
      case .directory:
        color = .blue
      default:
        color = .none
      }
      // This could be better, but for now I only care about
      // regular files that are executable.
      if type == .regular && executable {
        color = .red
      }

      return
        "\(color.rawValue)\(leading)\(name)\(ANSIColor.grey.rawValue)\(trailing)\(ANSIColor.reset.rawValue)"
    } else {
      return "\(leading)\(name)\(trailing)"
    }
  }
}

@main
struct List: ParsableCommand {
  @Argument(help: "Directory path to list contents of")
  var path: String?

  mutating func run() throws {
    var entries: [Entry] = try directoryEntries(at: path ?? ".")

    entries.sort {
      switch ($0.type, $1.type) {
      case (.directory, .directory):
        $0.sortKey < $1.sortKey
      case (.directory, _):
        true
      case (_, .directory):
        false
      default:
        $0.sortKey < $1.sortKey
      }
    }

    let useColor = stdoutIsTerminal()

    print("")
    for entry in entries {
      print(entry.formatted(useColor: useColor))
    }
  }
}
