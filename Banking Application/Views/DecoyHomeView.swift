import SwiftUI

/// Shown for a duress passcode. Balances are placeholders and money movement
/// is refused in `TransactionService`. The copy does not mention another passcode.
struct DecoyHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Available", value: "₹0.00")
                    LabeledContent("Accounts", value: "0")
                }
                Section {
                    Text("No recent activity")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "Accounts"))
        }
    }
}

struct StepUpPasscodeSheet: View {
    @EnvironmentObject private var authenticationService: AuthenticationService
    @State private var passcode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Enter your app passcode")
                    .font(.headline)
                SecureField("Passcode", text: $passcode)
                    .keyboardType(.numberPad)
                    .textContentType(.password)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Confirm") {
                    authenticationService.submitStepUpPasscode(passcode)
                }
                .buttonStyle(.borderedProminent)
                .disabled(passcode.count != 4)
            }
            .padding()
            .navigationTitle("Confirm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { authenticationService.cancelStepUp() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
