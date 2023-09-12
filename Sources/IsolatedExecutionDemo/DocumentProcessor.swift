import Distributed
import DistributedCluster
import Logging

distributed actor DocumentProcessor<T>: Codable where T: Codable  {
    
    typealias WorkItem = DocumentWorkItem

    private let workerID: String
    private lazy var log: Logger = .init(actor: self)

    private let workItem: DistObject<T>
    
    private var stepIndex = -1
    private var state: State = .initialized
    private var desiredState: State? = nil

    // The following are some names for steps to be executed in the according order
    // (the execution will only be simulated).
    private let steps = ["step1", "step2", "step3", "step4"]

    init(workerID: WorkerID, workItem: DistObject<T>, actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
        self.workerID = workerID
        self.workItem = workItem
        self.log.info("\(self.workerID) joined the cluster!")
    }

    distributed func process() {
        guard self.state != .stopped && self.state != .finished else { return }

        while stepIndex + 1 < steps.count {
            print("hellooo")


            self.state = .running
            stepIndex += 1

            // simulate the step:
            let slowdown = Double.random(in: 1.0..<1.5)
            // try await Task.sleep(nanoseconds: UInt64(workItem.documentSize / Double(steps.count) * slowdown * Double(NSEC_PER_SEC)))
        }

        if case .takingDistObject = self.state {
            Task {
                try await workItem.putBack()
                self.log.info("\(self.workerID) put back DistObject!")
            }
        }

        self.state = .sending
        Task {
            try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
            // await self.attemptToTakeDistObject()
        }
        self.log.info("\(self.workerID) is sending...")
    }

    func handle(control: Control) async throws {
        switch control {
        case .start:
            self.process()
        case .pause:
            self.desiredState = .paused
        case .resume:
            self.process()
        case .stop:
            self.desiredState = .stopped
        }
    }

    // distributed func attemptToTakeDistObject() async {
    //     guard self.state == .sending else {
    //         self.log.error("\(self.workerID) tried to take dist object but was not in the sending state")
    //         return
    //     }

    //     self.state = .takingDistObject

    //     do {
    //         let tookLeft = try await self.workItem.take()
    //         guard tookLeft else {
    //             self.process()
    //             return
    //         }
    //         self.distObjectTaken(self.workItem)
    //     } catch {
    //         self.log.info("\(self.workerID) wasnt able to take both dist objects!")
    //         self.process()
    //     }
    // }

    // private func distObjectTaken(_ distObject: DistObject<T>) {
    //     if self.state == .sending { // We couldn't get the dist object and have already gone back to sending.
    //         Task { try await distObject.putBack() }
    //         return
    //     }

    //     guard case .takingDistObject = self.state else {
    //         self.log.error("Received distObject \(distObject) but was not in .takingDistObject state. State was \(self.state)! Ignoring...")
    //         Task { try await distObject.putBack() }
    //         return
    //     }

    //     switch distObject {
    //     case self.workItem:
    //         self.log.info("\(self.workerID) received their distObject!")
    //         self.state = .takingDistObject
    //     default:
    //         self.log.error("Received unknown distObject! Got: \(distObject). Known distObject: \(self.workItem)")
    //     }
    // }
}

extension DocumentProcessor {
    private enum State: Equatable {
        case sending
        case takingDistObject
        case initialized
        case running
        case paused
        case stopped
        case finished
    }
}
