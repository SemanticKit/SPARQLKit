import Foundation
import Testing

/// The bytes of a fixture file, by its file name.
func fixture(_ fileName: String) throws -> Data {
    let file = URL(fileURLWithPath: fileName)
    let url = try #require(
        Bundle.module.url(forResource: file.deletingPathExtension().lastPathComponent, withExtension: file.pathExtension)
    )
    return try Data(contentsOf: url)
}
