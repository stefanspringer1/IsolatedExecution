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
        if case .takingDistObject = self.state {
            Task {
                try await data.putBack()
                self.log.info("\(self.name) put back DistObject!")
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

        self.state = .takingDistObject

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

    private func distObjectTaken(_ distObject: DistObject<T>) {
        if self.state == .sending { // We couldn't get the dist object and have already gone back to sending.
            Task { try await distObject.putBack() }
            return
        }

        guard case .takingDistObject = self.state else {
            self.log.error("Received distObject \(distObject) but was not in .takingDistObject state. State was \(self.state)! Ignoring...")
            Task { try await distObject.putBack() }
            return
        }

        switch distObject {
        case self.data:
            self.log.info("\(self.name) received their distObject!")
            self.state = .takingDistObject
        default:
            self.log.error("Received unknown distObject! Got: \(distObject). Known distObjects: \(self.data), \(self.rightFork)")
        }
    }
}

extension IsolatedActor {
    private enum State: Equatable {
        case sending
        case takingDistObject
        case eating
    }
}
