import Distributed
import DistributedCluster

/// The worker ID is a String, it has to unique.
public typealias WorkerID = String

/// The work item type can be anything, but is has to conform to this protocol,
/// i.e. it has to provide a work item ID which will be used as worker ID.
public protocol WorkItemWithID {
    var id: WorkerID { get }
}

/// This is for the communication from the worker to the orchestration.
/// Besides communicating status (stopped etc.) or progress, a message can be passed of a choosen type.
public enum BackCommunication<Message> {
    case progress(percent: Double, description: String); case stopped; case paused; case resumed; case finished; case message(message: Message)
}

/// This is the function type for a function that handles the communication from the worker to the orchestration.
public typealias BackCommunicationHandler<Message> = (WorkerID,BackCommunication<Message>) async throws -> ()

// This is how the worker can be controled.
public enum Control: Codable {
    case start  /// Start the worker.
    case pause  /// Pause the worker.
    case resume /// Resume the worker.
    case stop   /// Stop the worker.
}

/// This is a worker (or "processor") for a work item.
/// I.e. the work for that item is done here!
public protocol WorkItemProcessor<WorkItem> where WorkItem: WorkItemWithID {
    
    associatedtype WorkItem
    
    init(workerID: WorkerID, workItem: WorkItem, actorSystem: ClusterSystem)
    func process() async throws
    
    func handle(control: Control) async throws
    
}

/// For the orchestration of the work, a function has to be provided which return a processor for a given work item.
typealias WorkItemProcessorProducer<WorkItem> = (WorkItem, WorkerID, ClusterSystem) async -> DocumentProcessor where WorkItem: WorkItemWithID, WorkerID: CustomStringConvertible

final class WorkOrchestration<WorkItem, Message> where WorkItem: WorkItemWithID {
    var workitemsWaiting: [WorkItem]

    var workitemsFailedStarted = [WorkerID:WorkItem]()
    var workitemsStarted = [WorkerID:(workItem: WorkItem,processor: any WorkItemProcessor)]()
    var workitemsStopped = [WorkerID:(workItem: WorkItem,processor: any WorkItemProcessor)]()
    var workitemsFinsihed = [WorkerID:WorkItem]()

    
    private var DocumentProcessors: [DocumentProcessor] = []

    let parallelWorkers: Int

    private let workItemProcessorProducer: WorkItemProcessorProducer<WorkItem>
    private let logger: Logger

    var workerCount = 0

    init(
        workItemsStack: [WorkItem], 
        parallelWorkers: Int,
        workItemProcessorProducer: @escaping WorkItemProcessorProducer<WorkItem>,
        logger: Logger
    ){
        self.workitemsWaiting = workItemsStack
        self.parallelWorkers = parallelWorkers
        self.workItemProcessorProducer = workItemProcessorProducer
        self.logger = logger
    }

    @discardableResult
    private func startNextWorker() async -> Bool {
        guard let workItem: WorkItem = workitemsWaiting.popLast() else {
            print("All done!")
            return false
        }

        workerCount += 1
        let workerID = workItem.id
        let clusterSystem = await clusterProducer(workerID: workerID, port: 2000 + workerCount)
        let workItemProcessor: DocumentProcessor = await documentProcessorProducer(workItem as! DocumentWorkItem, workerID, clusterSystem)

        do{
            // workitemsStarted[workerID] = (workItem,workItemProcessor)
            print("starting #\(workerID) worker for \(workItem)")
            try await workItemProcessor.process()
        } catch{
            print("failed starting worker for \(workItem)")
        }

        return true
    }

    func run(for duration: Duration) async throws {
        print("WorkItemWaitung: ", workitemsWaiting.count)
        for _ in 1...parallelWorkers {
            if await !startNextWorker() {
                break
            }
        }

        // let systemA = await clusterProducer(workerID: "Node-A", port: 1111)
        // let systemB = await clusterProducer(workerID: "Node-B", port: 2222)
        // let systemC = await clusterProducer(workerID: "Node-C", port: 3333)
        // let systems = [systemA, systemB, systemC]

        // print("~~~~~~~ started \(systems.count) actor systems ~~~~~~~")

        // systemA.cluster.join(endpoint: systemB.settings.endpoint)
        // systemA.cluster.join(endpoint: systemC.settings.endpoint)
        // systemC.cluster.join(endpoint: systemB.settings.endpoint)

        // print("waiting for cluster to form...")
        // try await self.ensureCluster(systems, within: .seconds(10))

        // print("~~~~~~~ systems joined each other ~~~~~~~")

        // // prepare 5 DistObjects, that the DocumentProcessors will send each other:
        // // Node A
        // let distObject1 = DistObject<String>(value: "hello-1", id: "id-1")
        // // Node B
        // let distObject2 = DistObject<String>(value: "hello-2", id: "id-2")
        // let distObject3 = DistObject<String>(value: "hello-3", id: "id-3")
        // // Node C
        // let distObject4 = DistObject<String>(value: "hello-4", id: "id-4")
        // let distObject5 = DistObject<String>(value: "hello-5", id: "id-5")

        
        // // // 5 DocumentProcessors, exchanging DistObjects between them:
        // self.DocumentProcessors = [
        // // Node A
        //     DocumentProcessor(workerID: "Actor1", workItem: distObject5, actorSystem: systemA),
        // // Node B
        //     DocumentProcessor(workerID: "Actor2", workItem: distObject1, actorSystem: systemB),
        //     DocumentProcessor(workerID: "Actor3", workItem: distObject2, actorSystem: systemB),
        // // Node C
        //     DocumentProcessor(workerID: "Actor4", workItem: distObject3, actorSystem: systemC),
        //     DocumentProcessor(workerID: "Actor5", workItem: distObject4, actorSystem: systemC),
        // ]

        // sending dist objects
        // try await self.DocumentProcessors[0].process()

        // try systemA.park(atMost: duration)
    }

    /// from the worker to the orchestration:
    // func backCommunication(workerID: WorkerID, message: BackCommunication<Message>) async {
    //     switch message {
    //     case .progress(percent: let percent, description: let description):
    //         await logger.log(sourceID: workerID, "progress \(percent) %: \(description)")
    //     case .finished:
    //         await logger.log(sourceID: workerID, "finished")
    //         if let (workItem,_) = workitemsStarted[workerID] {
    //             workitemsStarted[workerID] = nil
    //             workitemsFinsihed[workerID] = workItem
    //         }
    //         await startNextWorker()
    //     case .message(message: let message):
    //         await logger.log(sourceID: workerID, message.description)
    //     case .stopped:
    //         if let entry = workitemsStarted[workerID] {
    //             workitemsStarted[workerID] = nil
    //             workitemsStopped[workerID] = entry
    //         }
    //         await logger.log(sourceID: workerID, "worker stopped!")
    //         await startNextWorker()
    //     case .paused:
    //         await logger.log(sourceID: workerID, "worker paused!")
    //     case .resumed:
    //         await logger.log(sourceID: workerID, "worker resumed...")
    //     }
        
    // }

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
