import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @State private var editingCategory: ExpenseCategory?
    @State private var showingNewCategory = false

    var body: some View {
        List {
            Section {
                ForEach(tracker.visibleCategories) { category in
                    BudgetRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture { editingCategory = category }
                }
            } header: {
                Text("This Month")
            } footer: {
                Text("Tap a category to set or edit its monthly budget.")
            }

            Section {
                Button {
                    showingNewCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Budgets")
        .sheet(isPresented: Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )) {
            if let editingCategory {
                BudgetEditorView(category: editingCategory)
            }
        }
        .sheet(isPresented: $showingNewCategory) {
            NewCategoryView()
        }
    }
}

private struct BudgetRow: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    let category: ExpenseCategory

    private var budget: Budget? { tracker.budget(for: category.id) }
    private var spent: Decimal { tracker.amountSpent(categoryId: category.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: category.systemImage)
                    .foregroundStyle(category.color)
                    .frame(width: 22)
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let budget {
                    Text("\(CurrencyFormatter.shared.string(from: spent)) of \(CurrencyFormatter.shared.string(from: budget.limitAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No budget set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let budget {
                ProgressView(value: min(progressFraction(budget: budget), 1.0))
                    .tint(progressColor(budget: budget))

                HStack {
                    Text(statusLabel(budget: budget))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(progressColor(budget: budget))
                    Spacer()
                    Text(remainingLabel(budget: budget))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func progressFraction(budget: Budget) -> Double {
        guard budget.limitAmount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / budget.limitAmount).doubleValue
    }

    private func progressColor(budget: Budget) -> Color {
        switch tracker.status(for: budget) {
        case .onTrack: return .green
        case .approaching: return .orange
        case .over: return .red
        }
    }

    private func statusLabel(budget: Budget) -> String {
        tracker.status(for: budget).label
    }

    private func remainingLabel(budget: Budget) -> String {
        let remaining = budget.limitAmount - spent
        if remaining >= 0 {
            return "\(CurrencyFormatter.shared.string(from: remaining)) left"
        } else {
            return "\(CurrencyFormatter.shared.string(from: abs(remaining))) over"
        }
    }
}

private struct BudgetEditorView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    let category: ExpenseCategory
    @State private var limitText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(category.color)
                        Text(category.name)
                    }
                }

                Section("Monthly limit") {
                    TextField("0.00", text: $limitText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                if let existing = tracker.budget(for: category.id) {
                    Section {
                        Button("Remove Budget", role: .destructive) {
                            tracker.removeBudget(existing)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Set Budget")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = Decimal(string: limitText) {
                            tracker.setBudget(categoryId: category.id, limitAmount: amount)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(Decimal(string: limitText) == nil)
                }
            }
            .onAppear {
                if let existing = tracker.budget(for: category.id) {
                    limitText = NSDecimalNumber(decimal: existing.limitAmount).stringValue
                }
            }
        }
    }
}

private struct NewCategoryView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "tag.fill"
    @State private var selectedColorHex = "6C5CE7"

    private let iconChoices = [
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "airplane",
        "gift.fill", "pawprint.fill", "gamecontroller.fill", "book.fill",
        "hammer.fill", "leaf.fill", "heart.fill", "sportscourt.fill"
    ]
    private let colorChoices = [
        "6C5CE7", "34C759", "FF9500", "5AC8FA", "FF3B30",
        "AF52DE", "FF2D55", "FFCC00", "30D158", "007AFF"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconChoices, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(selectedIcon == icon ? Color(hex: selectedColorHex)?.opacity(0.2) ?? Color.bankGroupedBackground : Color.bankGroupedBackground, in: Circle())
                                .foregroundStyle(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? .primary) : .primary)
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colorChoices, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().strokeBorder(.primary, lineWidth: selectedColorHex == hex ? 2 : 0)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        tracker.addCategory(name: name, systemImage: selectedIcon, colorHex: selectedColorHex)
                        if tracker.error == nil { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
