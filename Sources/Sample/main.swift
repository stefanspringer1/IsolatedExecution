import IsolatedExecution

struct MyData: DistObject {
    let message: String
}

let actorA = IsolatedExecution()
let actorB = IsolatedExecution()

async {
    // create message
    let data = MyData(message: "Hello from Actor A!")
    try await actorA.store(data)

    // send: actorA -> actorB
    try await actorA.send(to: actorB)

    // receive: actorB <- actorA
    if let receivedData = try await actorB.retrieve() as? MyData {
        print("Actor B received message: \(receivedData.message)")
    } else {
        print("No data received by Actor B.")
    }
}