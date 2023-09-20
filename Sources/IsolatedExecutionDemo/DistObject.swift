import Foundation

struct DocumentWorkItem: Equatable, Codable {
    let id: Int
    let documentURL: URL

    init(id: Int, documentURL: URL) {
        self.id = id
        self.documentURL = documentURL
    }
}