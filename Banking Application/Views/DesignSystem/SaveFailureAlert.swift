import SwiftUI
import SwiftData

extension Ledger {
    static let saveFailedMessage = "Your change couldn't be saved. Please try again."

    /// Saves a change that does not move money. On failure models inserted and not
    /// yet saved are dropped, `error` receives a message for `saveFailureAlert`, and
    /// this returns `false`, so callers only clear their form when it returns `true`.
    @discardableResult
    static func saveOrReport(_ context: ModelContext, error report: Binding<String?>) -> Bool {
        do {
            try save(context, discardingInsertsOnFailure: true)
            return true
        } catch {
            report.wrappedValue = saveFailedMessage
            return false
        }
    }
}

extension View {
    /// Shows the message set by `Ledger.saveOrReport` and clears it on dismiss.
    func saveFailureAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Couldn't save",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
