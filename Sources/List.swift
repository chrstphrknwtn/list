import ArgumentParser
import Foundation

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case purple = "\u{001B}[35m"
    case blue = "\u{001B}[34m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case dim = "\u{001B}[2m"
}

let fileAttributeKeys: [URLResourceKey] = [
    .isSymbolicLinkKey,
    .isExecutableKey,
    .isDirectoryKey,
    .isHiddenKey
]

let ignoredFiles: Set<String> = [".DS_Store"]

func formatOutput(_ url: URL) throws -> String {
    let rv = try url.resourceValues(
        forKeys: Set(fileAttributeKeys)
    )
    
    var color: ANSIColor
    switch true {
    case rv.isSymbolicLink ?? false:
        color = .purple
    case rv.isDirectory ?? false:
        color = .blue
    case rv.isExecutable ?? false:
        color = .red
    default:
        color = .white
    }
    
    // Hanging . for hidden files to align filenames
    let isHidden = (rv.isHidden ?? false) && url.lastPathComponent.hasPrefix(".")
    let outputString = "\(isHidden ? " " : "  ")\(color.rawValue)\(url.lastPathComponent)\(ANSIColor.reset.rawValue)"
    
    if rv.isSymbolicLink ?? false {
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        return "\(outputString)\(ANSIColor.dim.rawValue) -> \(destination)\(ANSIColor.reset.rawValue)"
    } else {
        return outputString
    }
}

@main
struct List: ParsableCommand {
    @Argument(help: "Directory path to list contents of")
    var path: String?
    
    mutating func run() throws {
        let dirPath = path ?? FileManager.default.currentDirectoryPath
        
        var contents = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: dirPath),
            includingPropertiesForKeys: fileAttributeKeys
        ).filter { !ignoredFiles.contains($0.lastPathComponent) }
        
        // Sort directories before files
        contents.sort { url1, url2 in
            let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            
            if isDir1 && !isDir2 {
                return true
            } else if !isDir1 && isDir2 {
                return false
            } else {
                // Strip leading dots for sorting to handle hidden files properly
                let name1 = url1.lastPathComponent
                let name2 = url2.lastPathComponent
                let sortName1 = name1.hasPrefix(".") ? String(name1.dropFirst()) : name1
                let sortName2 = name2.hasPrefix(".") ? String(name2.dropFirst()) : name2
        
                return sortName1.localizedStandardCompare(sortName2) == .orderedAscending
            }
        }
        
        // A little breathing room
        print("")
        
        for url in contents {
            if let output = try? formatOutput(url) {
                print(output)
            } else {
                print("  \(ANSIColor.red.rawValue)Error: \(url.lastPathComponent)\(ANSIColor.reset.rawValue)")
            }
        }
    }
}
