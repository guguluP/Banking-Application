import SwiftUI

/// The Track tab's privacy/trust surface — separate from the main app's
/// `PrivacyAndSecurityView`, since this one is specifically about the
/// expense-tracking data (natural-language text, receipt photos, spending
/// history) and what happens to it, which is a different promise than the
/// banking app's account-security settings.
struct ExpenseTrackerPrivacyView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingWipeConfirmation = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("All processing happens on your device", systemImage: "iphone")
                            .font(.subheadline.weight(.semibold))
                        Text("Natural-language parsing and receipt scanning run entirely on-device using Apple's on-device frameworks. Your expense text and receipt photos are never sent to a server, and no cloud AI processes them by default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy")
                }

                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        privacyPoint(icon: "lock.shield.fill", text: "Your data is stored locally and synced only to your own iCloud account.")
                        privacyPoint(icon: "eye.slash.fill", text: "Nobody else — including Anthropic — can see this data.")
                        privacyPoint(icon: "trash.fill", text: "You can export or permanently delete your tracking data at any time, below.")
                    }
                } header: {
                    Text("What this means")
                }

                Section {
                    Button {
                        exportData()
                    } label: {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    if let exportError {
                        Text(exportError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Exports every expense you've logged — date, merchant, category, amount, and notes — as a CSV file you can open in any spreadsheet app.")
                }

                Section {
                    Button(role: .destructive) {
                        showingWipeConfirmation = true
                    } label: {
                        Label("Delete All Tracking Data", systemImage: "trash.fill")
                    }
                } footer: {
                    Text("Permanently deletes every expense, category, and budget you've created here, and reverses their effect on your account balances. This does not affect your accounts, cards, or other banking activity.")
                }
            }
            .navigationTitle("Privacy & Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete all tracking data?", isPresented: $showingWipeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    tracker.wipeAllTrackerData()
                }
            } message: {
                Text("This can't be undone. Consider exporting a CSV first.")
            }
            .sheet(item: Binding(
                get: { exportURL.map { IdentifiableURL(url: $0) } },
                set: { exportURL = $0?.url }
            )) { wrapped in
                ShareSheet(items: [wrapped.url])
            }
        }
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Color.bankPrimary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func exportData() {
        exportError = nil
        do {
            let csv = tracker.exportCSV()
            exportURL = try ExpenseDataExporter.writeToTemporaryFile(csv: csv)
        } catch {
            exportError = "Couldn't create the export file. Please try again."
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
