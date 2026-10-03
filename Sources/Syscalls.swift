#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#else
  #error("Unsupported platform")
#endif

func stdoutIsTerminal() -> Bool {
  isatty(STDOUT_FILENO) != 0
}

func directoryEntries(at path: String) throws -> [Entry] {
  guard let dir = opendir(path) else {
    let reason = String(cString: strerror(errno))
    throw ListError(description: "Cannot open directory at \(path): \(reason)")
  }
  defer {
    closedir(dir)
  }

  var entries: [Entry] = []

  while true {
    errno = 0
    guard let ent = readdir(dir) else {
      if errno != 0 {
        let reason = String(cString: strerror(errno))
        throw ListError(description: "Error reading directory at \(path): \(reason)")
      }
      break
    }

    let name = entryName(ent)
    if [".", "..", ".DS_Store"].contains(name) { continue }

    var st = stat()
    let statSucceeded = fstatat(dirfd(dir), name, &st, AT_SYMLINK_NOFOLLOW) == 0

    let type: EntryType = statSucceeded ? entryType(st.st_mode) : .unknown

    let symlinkDest =
      type == .symlink
      ? readSymlink(dir: dirfd(dir), name: name, sizeHint: Int(st.st_size))
      : nil

    let entry = Entry(
      name: name,
      type: type,
      symlinkDest: symlinkDest,
      executable: isExecutable(st.st_mode)
    )
    entries.append(entry)
  }
  return entries
}

private func entryName(_ dirent: UnsafeMutablePointer<dirent>) -> String {
  withUnsafePointer(to: &dirent.pointee.d_name) { tuplePtr in
    tuplePtr.withMemoryRebound(
      to: CChar.self,
      capacity: MemoryLayout.size(ofValue: tuplePtr.pointee)
    ) {
      String(cString: $0)
    }
  }
}

private func entryType(_ mode: mode_t) -> EntryType {
  switch mode & mode_t(S_IFMT) {
  case mode_t(S_IFIFO): .fifo
  case mode_t(S_IFCHR): .character
  case mode_t(S_IFDIR): .directory
  case mode_t(S_IFBLK): .block
  case mode_t(S_IFREG): .regular
  case mode_t(S_IFLNK): .symlink
  case mode_t(S_IFSOCK): .socket
  default: .unknown
  }
}

private func readSymlink(dir: Int32, name: String, sizeHint: Int) -> String? {
  let capacity = sizeHint > 0 ? sizeHint + 1 : Int(PATH_MAX)
  var buffer = [CChar](repeating: 0, count: capacity)

  let count = readlinkat(dir, name, &buffer, buffer.count)
  guard count >= 0 else { return nil }

  let bytes = buffer[..<count].map { UInt8(bitPattern: $0) }
  return String(decoding: bytes, as: UTF8.self)
}

private func isExecutable(_ mode: mode_t) -> Bool {
  let canExecute = mode_t(S_IXUSR) | mode_t(S_IXGRP) | mode_t(S_IXOTH)
  return mode & canExecute != 0
}
