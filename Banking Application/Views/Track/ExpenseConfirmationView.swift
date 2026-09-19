import SwiftUI
import SwiftData

/// The single save path for every way an expense enters the app — typed
/// Quick-Add, natural-language parsing, and receipt OCR all end here.
/// Nothing from NL parsing or OCR is ever saved without passing through
/// this editable confirmation step first.
struct ExpenseConfirmationView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @Environment(\.dismiss) private var dismiss

    /// `nil` when creating a new entry; set when editing an existing one
    /// from the ledger.
    var editingTransaction: Transaction?

    @State private var amountText: String
    @State private var merchant: String
    @State private var notes: String
    @State private var selectedCategoryName: String
    @State private var date: Date
    @State private var selectedAccount: Account?
    @State private var isIncome: Bool
    @State private var receiptImage: UIImage?

    let confidence: Double?
    let entrySource: TransactionEntrySource
    let rawInputText: String?

    init(
        draft: ParsedExpenseDraft? = nil,
        editingTransaction: Transaction? = nil,
        receiptImage: UIImage? = nil,
        entrySource: TransactionEntrySource = .manualEntry,
        defaultAccount: Account? = nil
    ) {
        self.editingTransaction = editingTransaction
        self.confidence = draft?.confidence
        self.entrySource = editingTransaction?.entrySource ?? entrySource
        self.rawInputText = draft?.rawInputText

        if let editingTransaction {
            _amountText = State(initialValue: NSDecimalNumber(decimal: editingTransaction.amount).stringValue)
            _merchant = State(initialValue: editingTransaction.merchant ?? "")
            _notes = State(initialValue: editingTransaction.notes ?? "")
            _selectedCategoryName = State(initialValue: editingTransaction.categoryRef?.name ?? ExpenseCategory.otherCategoryName)
            _date = State(initialValue: editingTransaction.transactionDate)
            _isIncome = State(initialValue: editingTransaction.isCredit)
            _receiptImage = State(initialValue: nil)
        } else {
            _amountText = State(initialValue: draft?.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
            _merchant = State(initialValue: draft?.merchant ?? "")
            _notes = State(initialValue: "")
            _selectedCategoryName = State(initialValue: draft?.categoryName ?? ExpenseCategory.otherCategoryName)
            _date = State(initialValue: draft?.date ?? Date())
            _isIncome = State(initialValue: draft?.categoryName == ExpenseCategory.incomeCategoryName)
            _receiptImage = State(initialValue: receiptImage)
        }
        _selectedAccount = State(initialValue: defaultAccount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if let receiptImage {
                        Image(uiImage: receiptImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
                            .padding(.horizontal)
                    }

                    if let confidence, confidence < CategoryKeywordClassifier.lowConfidenceThreshold {
                        lowConfidenceBanner
                    }

                    if let rawInputText, entrySource == .naturalLanguage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You said")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(rawInputText)
                                .font(.subheadline)
                                .italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ModernTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        text: $amountText,
                        systemImage: "indianrupee.sign",
                        keyboardType: .decimalPad
                    )
                    .padding(.horizontal)

                    ModernTextField(
                        label: "Merchant / Payee",
                        placeholder: "e.g. Starbucks",
                        text: $merchant,
                        systemImage: "storefront"
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        AccountPicker(selection: $selectedAccount, accounts: accountViewModel.accounts)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        CategoryPickerGrid(
                            categories: tracker.visibleCategories,
                            selectedName: $selectedCategoryName
                        )
                    }
                    .padding(.horizontal)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                        .padding(.horizontal)

                    ModernTextField(
                        label: "Notes (optional)",
                        placeholder: "Add a note",
                        text: $notes,
                        systemImage: "note.text"
                    )
                    .padding(.horizontal)

                    if let error = tracker.error {
                        ErrorBannerModern(error: error)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .bankSoftScrollEdges()
            .navigationTitle(editingTransaction == nil ? "Confirm Expense" : "Edit Expense")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if selectedAccount == nil {
                    selectedAccount = accountViewModel.accounts.first(where: { $0.isPrimary }) ?? accountViewModel.accounts.first
                }
            }
        }
    }

    private var lowConfidenceBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Low confidence — please check the details below")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var isFormValid: Bool {
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }
        return selectedAccount != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountText), let account = selectedAccount else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedMerchant.isEmpty ? selectedCategoryName : trimmedMerchant
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingTransaction {
            tracker.updateExpense(
                editingTransaction,
                account: account,
                amount: amount,
                merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
                description: description,
                categoryName: selectedCategoryName,
                date: date,
                isIncome: isIncome
            )
        } else {
            tracker.addExpense(
                account: account,
                amount: amount,
                merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
                description: description,
                categoryName: selectedCategoryName,
                date: date,
                source: entrySource,
                isIncome: isIncome,
                receiptImageData: receiptImage?.jpegData(compressionQuality: 0.7),
                confidence: confidence,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        }

        if tracker.error == nil {
            dismiss()
        }
    }
}

/// A wrapping grid of category chips, used instead of a `Picker`/`Menu` so
/// every category (with its icon and color) is visible and tappable at
/// once — this is the primary "confirm the category" interaction, so it
/// should be fast, not buried in a dropdown.
struct CategoryPickerGrid: View {
    let categories: [ExpenseCategory]
    @Binding var selectedName: String

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(categories) { category in
                let isSelected = category.name == selectedName
                Button {
                    selectedName = category.name
                    HapticFeedbackService.shared.lightImpact()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.caption)
                        Text(category.name)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected ? category.color.opacity(0.18) : Color.bankGroupedBackground,
                        in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.pill, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.pill, style: .continuous)
                            .strokeBorder(isSelected ? category.color : .clear, lineWidth: 1.5)
                    )
                    .foregroundStyle(isSelected ? category.color : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}
