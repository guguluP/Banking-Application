import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Last updated: January 1, 2023")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TermsContent(searchText: searchText)
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .searchable(text: $searchText, prompt: "Search terms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityLabel("Close terms of service")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct TermsContent: View {
    let searchText: String
    
    private let allTerms: [(number: Int, title: String, content: String)] = [
        (1, "Introduction", "Welcome to BankSecure. These Terms of Service govern your use of our mobile application and services."),
        (2, "Account Registration", "To use our services, you must register for an account. You agree to provide accurate, current, and complete information during registration."),
        (3, "Security", "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account."),
        (4, "Transactions", "All transactions are subject to verification and may be delayed or blocked for security reasons."),
        (5, "Fees", "Please refer to our fee schedule for applicable charges."),
        (6, "Termination", "We reserve the right to terminate or suspend your account at any time, without prior notice or liability, for any reason whatsoever."),
        (7, "Disclaimer", "The service is provided on an \"as is\" and \"as available\" basis.")
    ]
    
    private var filteredTerms: [(number: Int, title: String, content: String)] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allTerms
        }
        let lowerSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allTerms.filter { term in
            term.title.lowercased().contains(lowerSearch) || term.content.lowercased().contains(lowerSearch)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if filteredTerms.isEmpty {
                Text("No terms found matching \"\(searchText)\"")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(filteredTerms, id: \.number) { term in
                    TermsSection(number: term.number, title: term.title, content: term.content)
                }
            }
        }
    }
}

struct TermsSection: View {
    let number: Int
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(number).")
                    .font(.headline)
                    .foregroundColor(Color.bankPrimary)
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

struct TermsOfServiceView_Previews: PreviewProvider {
    static var previews: some View {
        TermsOfServiceView()
    }
}