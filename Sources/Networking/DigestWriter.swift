import Foundation

/// Protocol to decouple the Networking layer from Services.
/// The App layer provides a concrete implementation backed by DigestFileManager.
public protocol DigestWriter {
    /// Replace the entire digest file for a source with the given items.
    func writeDigest(source: String, items: [DigestItem]) throws
    /// Return the file path for a source's digest file.
    func digestFilePath(for source: String) -> String
    /// Return the set of source tracking UUIDs already present in a digest file.
    func existingSourceIds(in filePath: String, for source: String) -> Set<String>
}
