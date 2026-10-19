//
//  LibrariesDevChrome.swift
//  Banking Application
//
//  Libraries.dev effects: liquid-metal send and payment CTAs, thinking
//  orbs for the on-device assistant, and a voice glow on the composer.
//

import SwiftUI
import Speech
import AVFoundation
import MetalFxKit
import BankThinkingOrbs
import BankVoiceGlow

// MARK: - Dictation (on-device)

@MainActor
@Observable
final class ChatDictationController {
    let meter = VoiceMeter()
    private(set) var isListening = false
    private(set) var hint: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var handlerID: UUID?
    private var baseText = ""
    private var onTranscript: ((String) -> Void)?

    func toggle(currentText: String, onTranscript: @escaping (String) -> Void) async {
        if isListening {
            stop()
            return
        }
        await start(currentText: currentText, onTranscript: onTranscript)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        if let handlerID {
            meter.removeBufferHandler(handlerID)
            self.handlerID = nil
        }
        meter.stop()
        isListening = false
        hint = nil
        onTranscript = nil
    }

    private func start(currentText: String, onTranscript: @escaping (String) -> Void) async {
        hint = nil
        baseText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onTranscript = onTranscript
        do {
            try await meter.start()
        } catch VoiceMeter.MeterError.permissionDenied {
            hint = "Allow the microphone to talk to the assistant."
            return
        } catch {
            hint = "The microphone isn't available right now."
            return
        }
        isListening = true
        await attachRecognizerIfPossible()
    }

    private func attachRecognizerIfPossible() async {
        let recognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
        guard let recognizer, recognizer.isAvailable else { return }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        self.recognizer = recognizer
        self.request = request
        let box = SpeechRequestBox(request)
        handlerID = meter.addBufferHandler { buffer in
            box.append(buffer)
        }
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    let combined = self.baseText.isEmpty ? spoken : self.baseText + " " + spoken
                    self.onTranscript?(combined)
                }
            }
        }
    }
}

private nonisolated final class SpeechRequestBox: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

// MARK: - Processing beam

enum VoiceProcessingMotion {
    static func travelling() -> VoiceGlowMotion {
        let t = Date().timeIntervalSinceReferenceDate
        return VoiceGlowMotion(
            gather: 0.88,
            offset: sin(t * 1.15) * 0.7,
            stretch: 0.28,
            heldLevel: 0.62,
            cornerFollow: 0.35
        )
    }
}

// MARK: - Send

struct LiquidMetalSendButton: View {
    var isBusy: Bool
    var isEnabled: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MetalFx(
            variant: .circle,
            preset: .chromatic,
            strength: isEnabled ? 0.95 : 0.45,
            innerShadow: true,
            glow: !reduceMotion,
            paused: reduceMotion,
            fill: Color.bankPrimary,
            id: "bank-send"
        ) {
            Button(action: action) {
                Image(systemName: isBusy ? "hourglass" : "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .accessibilityLabel("Send message")
    }
}

struct AssistantThinkingIndicator: View {
    var state: OrbState = .working
    var size: OrbSize = .px20
    var caption: String = "Thinking…"

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ThinkingOrb(state: state, size: size)
            ShimmerText(caption, font: .subheadline)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
    }
}

enum LiquidMetalPreset {
    case chromatic, silver, gold

    fileprivate var metal: MetalPreset {
        switch self {
        case .chromatic: return .chromatic
        case .silver: return .silver
        case .gold: return .gold
        }
    }
}

/// Metal ring around a primary payment CTA. The child keeps its own fill;
/// the shader only paints the rim.
struct LiquidMetalCTA<Content: View>: View {
    var id: String
    var preset: LiquidMetalPreset = .chromatic
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MetalFx(
            variant: .button,
            preset: preset.metal,
            strength: 0.88,
            innerShadow: true,
            glow: !reduceMotion,
            paused: reduceMotion,
            fill: .clear,
            id: id,
            content: content
        )
    }
}
