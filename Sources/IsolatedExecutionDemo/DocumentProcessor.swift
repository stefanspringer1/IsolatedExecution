import Distributed
import DistributedCluster
import Foundation

enum Control {
    case running
    case paused
    case completed
}

distributed actor DocumentProcessor {
    let workOrchestration: WorkOrchestration
    var workItem: DocumentWorkItem
    var control: Control = .running
    private var pauseContinuation: CheckedContinuation<Void, Never>?

    init(workItem: DocumentWorkItem, workOrchestration: WorkOrchestration, actorSystem: ClusterSystem) {
        self.workItem = workItem
        self.workOrchestration = workOrchestration
        self.actorSystem = actorSystem
    }

    distributed func work() async throws{
        for i in 1...4 {
            if control == .paused {
                // Warte, bis der Zustand nicht mehr 'paused' ist.
                await waitForResume()
            }
            try await workOrchestration.reportProgress(workItem: workItem, step: i)
            let randomSleep = UInt64(Int.random(in: 500_000_000...2_000_000_000))
            await Task.sleep(randomSleep)
        }
        control = .completed
        try await workOrchestration.reportCompletion(workItem: workItem)
    }

    distributed func pause() {
        control = .paused
    }

    distributed func resume() {
        control = .running
        pauseContinuation?.resume()
        pauseContinuation = nil
    }

    private func waitForResume() async {
        await withCheckedContinuation { continuation in
            self.pauseContinuation = continuation
        }
    }
}