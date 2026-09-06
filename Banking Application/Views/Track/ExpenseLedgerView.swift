import SwiftUI

struct ExpenseLedgerView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @State private var searchText = ""
    @State private var selectedCategoryId: String?
    @State private var editingTransaction: Transaction?
    @State private var transactionPendingDelete: Transaction?

    var body: some View {
        VStack(spacing: 0) {
            categoryFilterBar

            let entries = tracker.filteredEntries(searchText: searchText, categoryId: selectedCategoryId)

            if entries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedByDay(entries), id: \.date) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                ExpenseLedgerRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTransaction = entry }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            transactionPendingDelete = entry
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button {
                                            editingTransaction = entry
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(Color.bankPrimary)
                                    }
                            }
                        } header: {
                            Text(group.date, style: .date)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search expenses")
        .navigationTitle("Ledger")
        .sheet(isPresented: Binding(
            get: { editingTransaction != nil },
            set: { if !$0 { editingTransaction = nil } }
        )) {
            if let editingTransaction {
                ExpenseConfirmationView(editingTransaction: editingTransaction)
            }
        }
        .alert("Delete this entry?", isPresented: Binding(get: { transactionPendingDelete != nil }, set: { if !$0 { transactionPendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { transactionPendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let transaction = transactionPendingDelete {
                    tracker.deleteExpense(transaction)
                }
                transactionPendingDelete = nil
            }
        } message: {
            Text("This will remove the entry and restore the amount to your account balance.")
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(name: "All", isSelected: selectedCategoryId == nil) {
                    selectedCategoryId = nil
                }
                ForEach(tracker.visibleCategories) { category in
                    filterChip(
                        name: category.name,
                        systemImage: category.systemImage,
                        color: category.color,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = selectedCategoryId == category.id ? nil : category.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(name: String, systemImage: String? = nil, color: Color = .bankPrimary, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption2)
                }
                Text(name).font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.18) : Color.bankGroupedBackground, in: Capsule(style: .continuous))
            .foregroundStyle(isSelected ? color : Color.primary)
            .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            Text(searchText.isEmpty && selectedCategoryId == nil ? "No expenses logged yet" : "No matching expenses")
                .font(.headline)
            Text(searchText.isEmpty && selectedCategoryId == nil ? "Tap the + button to add your first one." : "Try a different search or filter.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private struct DayGroup {
        let date: Date
        let entries: [Transaction]
    }

    private func groupedByDay(_ entries: [Transaction]) -> [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.transactionDate) }
        return grouped
            .map { DayGroup(date: $0.key, entries: $0.value.sorted { $0.transactionDate > $1.transactionDate }) }
            .sorted { $0.date > $1.date }
    }
}

struct ExpenseLedgerRow: View {
    let entry: Transaction

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill((entry.categoryRef?.color ?? .secondary).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.categoryRef?.systemImage ?? "questionmark.circle")
                    .foregroundStyle(entry.categoryRef?.color ?? .secondary)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.merchant ?? entry.transactionDescription)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.categoryRef?.name ?? "Uncategorized")
                    if entry.entrySource != .manualEntry {
                        Text("·")
                        Image(systemName: entry.entrySource == .receiptScan ? "camera.fill" : "sparkles")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.formattedAmount)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.isCredit ? .green : .primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
