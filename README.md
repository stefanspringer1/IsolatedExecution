Please see the discussion in [this Swift forums topic](https://forums.swift.org/t/isolating-executions-by-using-distributed-actors/76531).

### Ausführung
https://github.com/apple/swift-distributed-actors/tree/main clonen und im Verzeichnis daneben ("../") ablegen.

---

### Verwendung
Erstellen von DocumentWorkItem Instanzen:
```swift
let workItem1 = DocumentWorkItem(id: 1, documentURL: URL(fileURLWithPath: "path/to/doc1"))
```

Initialisieren des WorkOrchestration Actors:
```swift
// Cluster für WorkOrchestration
let cluster = await ClusterSystem("Node-Orchestration") { settings in
    settings.bindPort = 1111
}

// Initialisiere WorkOrchestration
let orchestration = WorkOrchestration(workItems: [workItem1, workItem2], allDoneHandler: allDoneHandler, actorSystem: cluster)
```

Pausieren und Fortsetzen von Prozessen:
```swift
// Pausiere Prozess mit ID 1
await orchestration.pauseProcessor(withId: 1)

// Setzte Prozess mit ID 1 fort
await orchestration.resumeProcessor(withId: 1)
```
---

### Klassen und Strukturen
#### DocumentWorkItem
Diese Struktur repräsentiert ein Dokument, das verarbeitet werden soll.

* ```id```: Eindeutige ID des Dokuments.
* ```documentURL```: URL des Dokuments.


#### DocumentProcessor
Ein Actor, der für die Verarbeitung eines ```DocumentWorkItem`````` verantwortlich ist.

* ```work()```: Führt die Verarbeitung des Dokuments aus.
* ```pause()```: Pausiert die Verarbeitung.
* ```resume()```: Setzt die Verarbeitung fort.

#### WorkOrchestration
Ein Actor, der für die Koordination der DocumentProcessor-Instanzen verantwortlich ist.

* ```startWork()```: Startet die Arbeit für alle DocumentProcessor.
* ```pauseProcessor(withId id: Int)```: Pausiert den Prozessor mit der angegebenen ID.
* ```resumeProcessor(withId id: Int)```: Setzt den Prozessor mit der angegebenen ID fort.
