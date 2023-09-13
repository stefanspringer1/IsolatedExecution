import Foundation

/// The protocol for a logger.
public protocol Logger {
    func log(sourceID: String?, _ message: String) async
}

/// A simple logger that only prints.
actor PrintLogger: Logger {
    func log(sourceID: String?, _ message: String) async {
        if let sourceID {
            print("source \(sourceID): \(message)")
        } else {
            print(message)
        }
    }
}