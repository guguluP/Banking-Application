import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Last updated: January 1, 2023")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PolicySection(number: 1, title: "Information We Collect", content: "We collect personal information you provide to us such as your name, address, email address, phone number, and financial information.")
                    
                    PolicySection(number: 2, title: "How We Use Your Information", content: "We use your information to provide, maintain, and improve our services, to process transactions, and to communicate with you.")
                    
                    PolicySection(number: 3, title: "Information Sharing", content: "We do not sell your personal information to third parties. We may share information with service providers who assist us in operating our services.")
                    
                    PolicySection(number: 4, title: "Security", content: "We implement reasonable security measures to protect your personal information.")
                    
                    PolicySection(number: 5, title: "Your Rights", content: "You have the right to access, correct, or delete your personal information.")
                    
                    PolicySection(number: 6, title: "Changes to This Policy", content: "We may update our privacy policy from time to time.")
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close privacy policy")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct PolicySection: View {
    let number: Int
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(number).")
                    .font(.headline)
                    .foregroundColor(Color.bankSecondary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .accessibilityAddTraits(.isHeader)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}