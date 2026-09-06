import SwiftUI

/// The primary "add an expense" surface: a natural-language field up top
/// (item 5 — "Coffee and a croissant, ₹350") and a manual-entry button
/// below it (item 2) for when the user would rather just fill out fields
/// directly. Both paths converge on the same `ExpenseConfirmationView`.
struct QuickAddExpenseView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var nlText: String = ""
    @State private var parsedDraft: ParsedExpenseDraft?
    @State private var showingConfirmation = false
    @State private var showingReceiptCapture = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Describe your expense")
                        .font(.headline)
                    Text("e.g. \"Coffee and a croissant, ₹350\" or \"Uber to the airport ₹450 yesterday\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Type naturally...", text: $nlText, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($isTextFieldFocused)
                        .padding(12)
                        .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                        .submitLabel(.done)
                        .onSubmit(parseAndConfirm)

                    ModernButton(
                        title: "Parse Expense",
                        systemImage: "sparkles",
                        variant: nlText.trimmingCharacters(in: .whitespaces).isEmpty ? .glass : .filled
                    ) {
                        parseAndConfirm()
                    }
                    .disabled(nlText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                HStack {
                    Rectangle().fill(Color.bankSeparator).frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color.bankSeparator).frame(height: 1)
                }
                .padding(.horizontal)

                VStack(spacing: AppSpacing.md) {
                    ModernButton(
                        title: "Enter Manually",
                        systemImage: "square.and.pencil",
                        variant: .outlined
                    ) {
                        parsedDraft = nil
                        showingConfirmation = true
                    }

                    ModernButton(
                        title: "Scan a Receipt",
                        systemImage: "camera.viewfinder",
                        variant: .outlined
                    ) {
                        showingReceiptCapture = true
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, AppSpacing.lg)
            .navigationTitle("Add Expense")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isTextFieldFocused = true }
            .sheet(isPresented: $showingConfirmation) {
                ExpenseConfirmationView(draft: parsedDraft, entrySource: parsedDraft == nil ? .manualEntry : .naturalLanguage)
            }
            .sheet(isPresented: $showingReceiptCapture) {
                ReceiptCaptureView()
            }
        }
    }

    private func parseAndConfirm() {
        guard !nlText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        parsedDraft = ExpenseParsingService.shared.parse(nlText)
        HapticFeedbackService.shared.lightImpact()
        showingConfirmation = true
    }
}
