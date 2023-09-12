import Distributed
import DistributedCluster
import Logging
import NIO
import Foundation

typealias DefaultDistributedActorSystem = ClusterSystem

@main enum Main {
    static func main() async {
        print("===-----------------------------------------------------===")
        print("|            Isolated Execution Sample App                |")
        print("|                                                         |")
        print("|        USAGE: swift run IsolatedExecutionDemo           |")
        print("===-----------------------------------------------------===")

        LoggingSystem.bootstrap(SamplePrettyLogHandler.init)

        // let workitemsStack: [DistObject] = [
        //     DistObject<String>(value: "hello-1", actorSystem: systemA),
        //     DistObject<String>(value: "hello-2", actorSystem: systemB),
        //     DistObject<String>(value: "hello-3", actorSystem: systemB),
        //     DistObject<String>(value: "hello-4", actorSystem: systemC),
        //     DistObject<String>(value: "hello-5", actorSystem: systemC)
        // ]

        let workitemsStack: [DocumentWorkItem] = [
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/a"), documentSize: 2, id: "4"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/b"), documentSize: 4, id: "3"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/c"), documentSize: 1, id: "2"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/d"), documentSize: 3, id: "1"),
        ]

        /// Value that is used by the following handler.
        var finished = false
        
        /// This handler will be called when all work is done.
        let allDoneHandler = { finished = true }

        let duration = Duration.seconds(20)

        try! await WorkOrchestration<DocumentWorkItem>(workItemsStack: workitemsStack, parallelWorkers: 2).run(for: duration)
    }
}
