import Distributed
import DistributedCluster
import Logging
import NIO
import Foundation

typealias DefaultDistributedActorSystem = ClusterSystem

@main enum Main {
    static func main() async throws{
        print("===-----------------------------------------------------===")
        print("|            Isolated Execution Sample App                |")
        print("|                                                         |")
        print("|        USAGE: swift run IsolatedExecutionDemo           |")
        print("===-----------------------------------------------------===")


        // Value that is used by the following handler.
        var finished = false

        // This handler will be called when all work is done.
        let allDoneHandler = { finished = true }

        // Usage
        let cluster = await ClusterSystem("Node-Orchestration") { settings in
            settings.bindPort = 1111
        }

        let workItem1 = DocumentWorkItem(id: 1, documentURL: URL(fileURLWithPath: "/path/to/document1"))
        let workItem2 = DocumentWorkItem(id: 2, documentURL: URL(fileURLWithPath: "/path/to/document2"))
        let workItem3 = DocumentWorkItem(id: 3, documentURL: URL(fileURLWithPath: "/path/to/document3"))
        let workItems = [workItem1, workItem2, workItem3]

        let orchestration = try await WorkOrchestration(workItems: workItems, parallelWorkers: 2, allDoneHandler: allDoneHandler, actorSystem: cluster)

        // Start work in a background task.
        Task {
            try await orchestration.startWork()
        }


        // The following keeps the application alive until all work is done.
        // The according implementation in an actual application might be smarter!
        repeat {
            
            // Wait a bit before testing the `finished` value (again).
            try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))
            
            // The following code might stop a worker based on some random values.
            if Int.random(in: 1...10) == 1 {
                let randomProcessorId = Int.random(in: 1...workItems.count) 
                try await orchestration.pauseProcessor(withId: randomProcessorId)
                print("Paused processor with id \(randomProcessorId)!")

                await Task.sleep(2_000_000_000)
                try await orchestration.resumeProcessor(withId: randomProcessorId)
                print("Resumed processor with id \(randomProcessorId)!")
            }
            
        } while !finished

    }
}