import SwiftUI
import PhotosUI

/// Lets the user photograph a receipt or pick one from their library, runs
/// it through on-device Vision OCR, and hands the result to the same
/// confirmation sheet every other entry path uses.
struct ReceiptCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var scanError: String?
    @State private var parsedDraft: ParsedExpenseDraft?
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                        .fill(Color.bankGroupedBackground)
                        .frame(height: 260)

                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("Take a photo or choose one from your library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }

                    if isProcessing {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                            .fill(.black.opacity(0.35))
                        ProgressView("Reading receipt…")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                if let scanError {
                    ErrorBannerModern(error: .unknownError(scanError))
                        .padding(.horizontal)
                }

                VStack(spacing: AppSpacing.md) {
                    #if os(iOS)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        ModernButton(title: "Take Photo", systemImage: "camera.fill", variant: .filled) {
                            showingCamera = true
                        }
                    }
                    #endif

                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Text("Choose from Library")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.bankGroupedBackground, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.bankPrimary.opacity(0.45), lineWidth: 1.5))
                    .foregroundStyle(Color.bankPrimary)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Scan Receipt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingCamera) {
                CameraCaptureView(image: $capturedImage)
            }
            #endif
            .onChange(of: capturedImage) { _, newImage in
                guard let newImage else { return }
                Task { await processReceipt(newImage) }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        capturedImage = image
                    }
                }
            }
            .sheet(isPresented: $showingConfirmation, onDismiss: { dismiss() }) {
                ExpenseConfirmationView(draft: parsedDraft, receiptImage: capturedImage, entrySource: .receiptScan)
            }
        }
    }

    private func processReceipt(_ image: UIImage) async {
        isProcessing = true
        scanError = nil
        do {
            let draft = try await ReceiptScanService.shared.scan(image: image)
            parsedDraft = draft
            isProcessing = false
            showingConfirmation = true
        } catch {
            isProcessing = false
            scanError = error.localizedDescription
        }
    }
}

#if os(iOS)
/// Thin `UIViewControllerRepresentable` wrapper around `UIImagePickerController`
/// for camera capture — SwiftUI has no native camera-capture view as of this
/// deployment target, only `PhotosPicker` for the library.
struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
