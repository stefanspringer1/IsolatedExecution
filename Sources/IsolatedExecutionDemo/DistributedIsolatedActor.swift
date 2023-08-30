import DistributedCluster

final class DistributedIsolatedActor {
    private var isolatedActors: [IsolatedActor<String>] = []

    func run(for duration: Duration) async throws {
        let systemA = await ClusterSystem("Node-A") { settings in
            settings.bindPort = 1111
            settings.logging.logLevel = .error
        }
        let systemB = await ClusterSystem("Node-B") { settings in
            settings.bindPort = 2222
            // settings.logging.logLevel = .error
        }
        let systemC = await ClusterSystem("Node-C") { settings in
            settings.bindPort = 3333
            settings.logging.logLevel = .error
        }
        let systems = [systemA, systemB, systemC]

        print("~~~~~~~ started \(systems.count) actor systems ~~~~~~~")

        systemA.cluster.join(endpoint: systemB.settings.endpoint)
        systemA.cluster.join(endpoint: systemC.settings.endpoint)
        systemC.cluster.join(endpoint: systemB.settings.endpoint)

        print("waiting for cluster to form...")
        try await self.ensureCluster(systems, within: .seconds(10))

        print("~~~~~~~ systems joined each other ~~~~~~~")

        // prepare 5 DistObjects, that the IsolatedActors will send each other:
        // Node A
        let distObject1 = DistObject<String>(value: "fork-1", actorSystem: systemA)
        // Node B
        let distObject2 = DistObject<String>(value: "fork-2", actorSystem: systemB)
        let distObject3 = DistObject<String>(value: "fork-3", actorSystem: systemB)
        // Node C
        let distObject4 = DistObject<String>(value: "fork-4", actorSystem: systemC)
        let distObject5 = DistObject<String>(value: "fork-5", actorSystem: systemC)

        // // 5 IsolatedActors, exchanging DistObjects between them:
        self.isolatedActors = [
        // Node A
            IsolatedActor<String>(name: "Actor1", data: distObject5, actorSystem: systemA),
        // Node B
            IsolatedActor<String>(name: "Actor2", data: distObject1, actorSystem: systemB),
            IsolatedActor<String>(name: "Actor3", data: distObject2, actorSystem: systemB),
        // Node C
            IsolatedActor<String>(name: "Actor4", data: distObject3, actorSystem: systemC),
            IsolatedActor<String>(name: "Actor5", data: distObject4, actorSystem: systemC),
        ]

        try systemA.park(atMost: duration)
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
