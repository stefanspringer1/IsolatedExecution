import Distributed
import DistributedCluster
import Logging
import Foundation

distributed actor DocumentProcessor: Codable  {
    
    typealias WorkItem = DocumentWorkItem

    private let workerID: String
    // private lazy var log: Logger = .init(actor: self)

    private let workItem: WorkItem
    
    private var stepIndex = -1
    private var state: State = .initialized
    private var desiredState: State? = nil

    // The following are some names for steps to be executed in the according order
    // (the execution will only be simulated).
    private let steps = ["step1", "step2", "step3", "step4"]

    init(workerID: WorkerID, workItem: WorkItem, actorSystem: ClusterSystem) {
        self.actorSystem = actorSystem
        self.workerID = workerID
        self.workItem = workItem
        // self.log.info("\(self.workerID) joined the cluster!")
    }

    distributed func process() async throws{
        guard self.state != .stopped && self.state != .finished else { return }

        while stepIndex + 1 < steps.count {


            self.state = .running
            stepIndex += 1
            print(steps[stepIndex])

            // simulate the step:
            let slowdown = Double.random(in: 1.0..<1.5)
            Task{
                try await Task.sleep(nanoseconds: UInt64(workItem.documentSize / Double(steps.count) * slowdown * Double(NSEC_PER_SEC)))
            }

            self.state = .finished
        }

        self.state = .sending
        Task {
            try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
            // await self.attemptToTakeDistObject()
        }
        // self.log.info("\(self.workerID) is sending...")
    }

    distributed func handle(control: Control) async throws {
        switch control {
        case .start:
            try await self.process()
        case .pause:
            self.desiredState = .paused
        case .resume:
            try await self.process()
        case .stop:
            self.desiredState = .stopped
        }
    }
}

/// This function delivers a processor/worker for a given woerk item.
let documentProcessorProducer: WorkItemProcessorProducer = { (workItem,workerID,actorSystem) in
    DocumentProcessor(workerID: workerID, workItem: workItem, actorSystem: actorSystem)
}

extension DocumentProcessor {
    private enum State: Equatable {
        case sending
        case initialized
        case running
        case paused
        case stopped
        case finished
    }
}
