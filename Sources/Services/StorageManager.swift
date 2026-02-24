import Foundation

public final class StorageManager {
    public let effectiveRoot: String

    public init(graphPath: String?) {
        if let path = graphPath, !path.isEmpty {
            self.effectiveRoot = path
        } else {
            self.effectiveRoot = NSHomeDirectory() + "/.logseq-todos"
        }
        ensureDirectories()
    }

    public var journalsPath: String {
        (effectiveRoot as NSString).appendingPathComponent("journals")
    }

    public var pagesPath: String {
        (effectiveRoot as NSString).appendingPathComponent("pages")
    }

    private func ensureDirectories() {
        let fm = FileManager.default
        for dir in [journalsPath, pagesPath] {
            if !fm.fileExists(atPath: dir) {
                try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            }
        }
    }
}
