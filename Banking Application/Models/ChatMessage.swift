import Foundation

/// A single message in the in-app chatbot conversation.
struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    let date: Date

    init(id: UUID = UUID(), role: Role, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}
