import Distributed
import DistributedCluster
import Logging

distributed actor DistObject<T>: Codable where T: Codable {
    private lazy var log: Logger = {
        var l = Logger(actor: self)
        l[metadataKey: "value"] = "\(self.value)"
        return l
    }()

    private let value: T
    private var isTaken: Bool = false

    init(value: T, actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
        self.value = value
    }

    distributed func take() -> Bool {
        if self.isTaken {
            return false
        }

        self.isTaken = true
        return true
    }

    distributed func putBack() throws {
        guard self.isTaken else {
            self.log.error("Attempted to put back DistObject but was not taken!")
            throw ForkError.puttingBackNotTakenDistObject
        }
        self.isTaken = false
    }
}

enum ForkError: Error, Codable {
    case puttingBackNotTakenDistObject
}
