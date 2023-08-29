import Distributed
import DistributedCluster

// data have to be conform to the Codable protocol
protocol DistObject: Codable {}

distributed actor IsolatedExecution {
    
    public typealias ActorSystem = DistributedCluster

    private var data: DistObject?

    // store data in actor
    public func store(_ newData: DistObject) {
        self.data = newData
    }

    // receive data from other actors
    public func receive() -> DistObject? {
        return self.data
    }

    // send data to other actors
    public func send(to recipient: IsolatedExecution) async throws {
        guard let currentData = self.data else { 
            throw DistObjectError.noDataToSend
        }
        try await recipient.store(currentData)
    }
}

enum DistObjectError: Error {
    case noDataToSend
}