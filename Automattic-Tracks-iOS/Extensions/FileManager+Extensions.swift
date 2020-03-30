import Foundation

extension FileManager {

    var documentsDirectory: URL {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: documentsDirectory, isDirectory: true)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        return try self.contentsOfDirectory(atPath: url.path).map { url.appendingPathComponent($0) }
    }

    func contents(atUrl url: URL) -> Data? {
        return self.contents(atPath: url.path)
    }

    func fileExistsAtURL(_ url: URL) -> Bool {
        return self.fileExists(atPath: url.path)
    }

    func directoryExistsAtURL(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
