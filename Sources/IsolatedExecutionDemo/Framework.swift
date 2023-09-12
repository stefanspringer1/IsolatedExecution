import DistributedCluster

/// The worker ID is a String, it has to unique.
public typealias WorkerID = String

/// The work item type can be anything, but is has to conform to this protocol,
/// i.e. it has to provide a work item ID which will be used as worker ID.
public protocol WorkItemWithID {
    var id: WorkerID { get }
}

// This is how the worker can be controled.
public enum Control {
    case start  /// Start the worker.
    case pause  /// Pause the worker.
    case resume /// Resume the worker.
    case stop   /// Stop the worker.
}

final class WorkOrchestration<WorkItem> where WorkItem: WorkItemWithID {
    var workitemsWaiting: [WorkItem]
    private var DocumentProcessors: [DocumentProcessor<String>] = []
    let parallelWorkers: Int

    init(workItemsStack: [WorkItem], parallelWorkers: Int){
        self.workitemsWaiting = workItemsStack
        self.parallelWorkers = parallelWorkers
    }

    @discardableResult
    private func startNextWorker() async -> Bool {
        guard let workItem = workitemsWaiting.popLast() else {
            print("All done!")
            return false
        }

        let workerID = workItem.id

        print("hello workitem: ", workerID)
        return true
    }

    func run(for duration: Duration) async throws {

        for _ in 1...parallelWorkers {
            if await !startNextWorker() {
                break
            }
        }

        let systemA = await clusterProducer(workerID: "Node-A", port: 1111)
        let systemB = await clusterProducer(workerID: "Node-B", port: 2222)
        let systemC = await clusterProducer(workerID: "Node-C", port: 3333)
        let systems = [systemA, systemB, systemC]

        print("~~~~~~~ started \(systems.count) actor systems ~~~~~~~")

        systemA.cluster.join(endpoint: systemB.settings.endpoint)
        systemA.cluster.join(endpoint: systemC.settings.endpoint)
        systemC.cluster.join(endpoint: systemB.settings.endpoint)

        print("waiting for cluster to form...")
        try await self.ensureCluster(systems, within: .seconds(10))

        print("~~~~~~~ systems joined each other ~~~~~~~")

        // prepare 5 DistObjects, that the DocumentProcessors will send each other:
        // Node A
        let distObject1 = DistObject<String>(value: "hello-1", actorSystem: systemA)
        // Node B
        let distObject2 = DistObject<String>(value: "hello-2", actorSystem: systemB)
        let distObject3 = DistObject<String>(value: "hello-3", actorSystem: systemB)
        // Node C
        let distObject4 = DistObject<String>(value: "hello-4", actorSystem: systemC)
        let distObject5 = DistObject<String>(value: "hello-5", actorSystem: systemC)

        // // 5 DocumentProcessors, exchanging DistObjects between them:
        self.DocumentProcessors = [
        // Node A
            DocumentProcessor<String>(workerID: "Actor1", workItem: distObject5, actorSystem: systemA),
        // Node B
            DocumentProcessor<String>(workerID: "Actor2", workItem: distObject1, actorSystem: systemB),
            DocumentProcessor<String>(workerID: "Actor3", workItem: distObject2, actorSystem: systemB),
        // Node C
            DocumentProcessor<String>(workerID: "Actor4", workItem: distObject3, actorSystem: systemC),
            DocumentProcessor<String>(workerID: "Actor5", workItem: distObject4, actorSystem: systemC),
        ]

        // sending dist objects
        try await self.DocumentProcessors[0].process()

        try systemA.park(atMost: duration)
    }

    private func clusterProducer(workerID: WorkerID, port: Int) async -> ClusterSystem{
        return await ClusterSystem(workerID) { settings in
            settings.bindPort = port
            // settings.logging.logLevel = .error
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
