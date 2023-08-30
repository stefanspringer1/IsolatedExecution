import Distributed
import DistributedCluster
import Logging
import NIO

typealias DefaultDistributedActorSystem = ClusterSystem

@main enum Main {
    static func main() async {
        print("===-----------------------------------------------------===")
        print("|            Isolated Execution Sample App                |")
        print("|                                                         |")
        print("|        USAGE: swift run IsolatedExecutionDemo           |")
        print("===-----------------------------------------------------===")

        LoggingSystem.bootstrap(SamplePrettyLogHandler.init)

        let duration = Duration.seconds(20)

        try! await DistributedIsolatedActor().run(for: duration)
    }
}
