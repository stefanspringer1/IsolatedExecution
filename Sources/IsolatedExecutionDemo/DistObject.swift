import Distributed
import DistributedCluster
import Logging
import Foundation


/// A work item that represents a document given via an URL (e.g. a file on the disk).
struct DocumentWorkItem: CustomStringConvertible, WorkItemWithID {
    let documentURL: URL
    let documentSize: Double // document size will be translated into seconds for the processing
    let _id: String
    var id: String { _id }
    
    init(documentURL: URL, documentSize: Double, id: String) {
        self.documentURL = documentURL
        self.documentSize = documentSize
        self._id = id
    }
    
    public var description: String { "work item: document \(documentURL.description)" }
}

/// The message that is communicated by the processor/worker for a document,
/// which could describe errorts that occur while processing or other information.
struct DocumentProcessingMessage: CustomStringConvertible {
    let text: String
    var description: String { text }
}

struct DistObject<T>: WorkItemWithID, Codable where T: Codable {
    // private lazy var log: Logger = {
    //     var l = Logger(actor: self)
    //     l[metadataKey: "value"] = "\(self.value)"
    //     return l
    // }()

    private let value: T
    private var isTaken: Bool = false
    let _id: String
    var id: String { _id }

    public var description: String { "work item: document" }

    init(value: T, id: String) {
        // self.actorSystem = actorSystem
        self.value = value
        self._id = id
    }

    // distributed func take() -> Bool {
    //     if self.isTaken {
    //         return false
    //     }

    //     self.isTaken = true
    //     return true
    // }

    // distributed func putBack() throws {
    //     guard self.isTaken else {
    //         self.log.error("Attempted to put back DistObject but was not taken!")
    //         throw ForkError.puttingBackNotTakenDistObject
    //     }
    //     self.isTaken = false
    // }
}

enum ForkError: Error, Codable {
    case puttingBackNotTakenDistObject
}
