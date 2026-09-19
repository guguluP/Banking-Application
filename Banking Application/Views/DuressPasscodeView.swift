import SwiftUI

struct DuressPasscodeView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var code = ""
    @State private var message = "Choose a 4-digit code different from your login passcode."

    var body: some View {
        Form {
            SecureField("Duress passcode", text: $code)
                .keyboardType(.numberPad)
            Button("Save") {
                if authenticationService.setDuressPasscode(code) {
                    message = "Duress passcode saved. Using it at login opens a locked-down session."
                    code = ""
                } else {
                    message = "Use exactly 4 digits, and not your regular passcode."
                }
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Duress passcode")
        .sensitiveScreenShield()
    }
}
