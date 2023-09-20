import Distributed
import DistributedCluster

typealias AllDoneHandler = () -> Void

distributed actor WorkOrchestration {
    let workItems: [DocumentWorkItem]
    private var processors: [Int: DocumentProcessor] = [:]
    private var parallelWorkers: Int
    private var pendingWorkItems: [DocumentWorkItem]
    var workerSystems: [ClusterSystem] = []

    private let allDoneHandler: () -> ()

    init(workItems: [DocumentWorkItem], parallelWorkers: Int, allDoneHandler: @escaping AllDoneHandler, actorSystem: ClusterSystem) async throws{
        self.workItems = workItems
        self.pendingWorkItems = workItems
        self.parallelWorkers = parallelWorkers
        self.allDoneHandler = allDoneHandler
        self.actorSystem = actorSystem

        try await self.startWorkerCluster()
    }

    distributed func startWork() async throws{
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0...(parallelWorkers-1) {
                group.addTask {
                    do {
                        while let workItem = await self.takeNextWorkItem() {
                            let processor = await DocumentProcessor(workItem: workItem, workOrchestration: self, actorSystem: self.workerSystems[i])
                            await self.addProcessor(processor, for: workItem.id)
                            try await processor.work()
                        }
                    } catch {
                        // Fehlerbehandlung hier, z.B.:
                        print("Fehler beim Verarbeiten des WorkItems: \(error)")
                    }
                }
            }
        }

        // Alle Aufgaben sind abgeschlossen
        allDoneHandler()
    }

    distributed func reportProgress(workItem: DocumentWorkItem, step: Int) {
        print("Progress on workitem \(workItem.id): Step \(step)/4")
    }

    distributed func reportCompletion(workItem: DocumentWorkItem) {
        print("Completed workitem \(workItem.id)!")
    }

    // Methods to control a specific DocumentProcessor
    distributed func pauseProcessor(withId id: Int) async throws{
        try await processors[id]?.pause()
    }

    distributed func resumeProcessor(withId id: Int) async throws{
        try await processors[id]?.resume()
    }

    private func clusterProducer(workerID: String, port: Int) async -> ClusterSystem{
        return await ClusterSystem(workerID) { settings in
            settings.bindPort = port
        }
    }

    private func addProcessor(_ processor: DocumentProcessor, for workItemId: Int) {
        processors[workItemId] = processor
    }

    private func takeNextWorkItem() async -> DocumentWorkItem?{
        guard !pendingWorkItems.isEmpty else { return nil }
        return pendingWorkItems.removeFirst()
    }

    private func startWorkerCluster() async throws{
        for i in 0...(parallelWorkers-1) {
            let workerSystem = await ClusterSystem("Node-\(i)") { settings in
                settings.bindPort = 2000 + i
            }
            self.actorSystem.cluster.join(endpoint: workerSystem.settings.endpoint)
            workerSystems.append(workerSystem)

            print("waiting for cluster to form...")
            try await self.ensureCluster(workerSystems, within: .seconds(10))
        }
    }

    private func ensureCluster(_ systems: [ClusterSystem], within: Duration) async throws {
        let nodes = Set(systems.map(\.settings.bindNode))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for system in systems {
                group.addTask {
                    try await system.cluster.waitFor(nodes, .up, within: within)
                }
            }
            // loop explicitly to propagagte any error that might have been thrown
            for try await _ in group {}
        }
    }
}