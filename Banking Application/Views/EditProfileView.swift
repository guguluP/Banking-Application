import SwiftUI
import Combine
import SwiftData

struct EditProfileView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var isSaved = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Personal Information")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        GlassCard {
                            VStack(spacing: AppSpacing.md) {
                                ModernTextField(
                                    label: "First Name",
                                    placeholder: "Enter first name",
                                    text: $firstName,
                                    systemImage: "person"
                                )
                                
                                ModernTextField(
                                    label: "Last Name",
                                    placeholder: "Enter last name",
                                    text: $lastName,
                                    systemImage: "person"
                                )
                                
                                ModernTextField(
                                    label: "Email",
                                    placeholder: "Enter email",
                                    text: $email,
                                    systemImage: "envelope",
                                    keyboardType: .emailAddress
                                )
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }
                    
                    if isSaved {
                        SuccessBanner(message: "Saved successfully")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel editing")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                    .accessibilityLabel("Save profile changes")
                }
            }
            .onAppear {
                // Previously this screen started blank every time and never
                // wrote changes anywhere — edits looked like they saved but
                // vanished on the next visit.
                firstName = authenticationService.user?.firstName ?? ""
                lastName = authenticationService.user?.lastName ?? ""
                email = authenticationService.user?.email ?? ""
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private func saveProfile() {
        guard let user = authenticationService.user else { return }
        user.firstName = firstName
        user.lastName = lastName
        user.email = email

        do {
            try modelContext.save()
        } catch {
            HapticFeedbackService.shared.errorOccurred()
            return
        }

        withAnimation {
            isSaved = true
        }
        HapticFeedbackService.shared.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                isSaved = false
            }
            dismiss()
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
            .environmentObject(AuthenticationService())
            .modelContainer(PersistenceController.preview)
    }
}
