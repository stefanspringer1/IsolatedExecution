import Distributed
import DistributedCluster
import Logging

distributed actor IsolatedActor<T>: Codable where T: Codable  {
    private let name: String
    private lazy var log: Logger = .init(actor: self)

    private let data: DistObject<T>
    private var rightFork: DistObject<T>
    private var state: State = .sending

    init(name: String, data: DistObject<T>, actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
        self.name = name
        self.data = data
        self.rightFork = data
        self.log.info("\(self.name) joined the cluster!")

        Task {
//            context.watch(self.data)
//            context.watch(self.rightFork)
            try await self.send()
        }
    }

    distributed func send() {
        if case .takingDistObjects(let distObjectIsTaken, let rightIsTaken) = self.state {
            if distObjectIsTaken {
                Task {
                    try await data.putBack()
                    self.log.info("\(self.name) put back DistObject!")
                }
            }
        }

        self.state = .sending
        Task {
            try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
            await self.attemptToTakeDistObject()
        }
        self.log.info("\(self.name) is sending...")
    }

    distributed func attemptToTakeDistObject() async {
        guard self.state == .sending else {
            self.log.error("\(self.name) tried to take dist object but was not in the sending state")
            return
        }

        self.state = .takingDistObjects(leftTaken: false, rightTaken: false)

        do {
            let tookLeft = try await self.data.take()
            guard tookLeft else {
                self.send()
                return
            }
            self.distObjectTaken(self.data)
        } catch {
            self.log.info("\(self.name) wasnt able to take both dist objects!")
            self.send()
        }
    }

    distributed func stopSending() {
        self.log.info("\(self.name) is done eating and replaced both dist objects!")
        Task {
            do {
                try await self.data.putBack()
            } catch {
                self.log.warning("Failed putting back \(data): \(error)")
            }
        }
        self.send()
    }

    private func distObjectTaken(_ distObject: DistObject<T>) {
        if self.state == .sending { // We couldn't get the first fork and have already gone back to sending.
            Task { try await distObject.putBack() }
            return
        }

        guard case .takingDistObjects(let dataIsTaken, let rightForkIsTaken) = self.state else {
            self.log.error("Received distObject \(distObject) but was not in .takingDistObjects state. State was \(self.state)! Ignoring...")
            Task { try await distObject.putBack() }
            return
        }

        switch distObject {
        case self.data:
            self.log.info("\(self.name) received their left distObject!")
            self.state = .takingDistObjects(leftTaken: true, rightTaken: rightForkIsTaken)
        case self.rightFork:
            self.log.info("\(self.name) received their right distObject!")
            self.state = .takingDistObjects(leftTaken: dataIsTaken, rightTaken: true)
        default:
            self.log.error("Received unknown distObject! Got: \(distObject). Known distObjects: \(self.data), \(self.rightFork)")
        }
    }
}

extension IsolatedActor {
    private enum State: Equatable {
        case sending
        case takingDistObjects(leftTaken: Bool, rightTaken: Bool)
        case eating
    }
}
