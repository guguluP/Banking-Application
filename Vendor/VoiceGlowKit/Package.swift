// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BankVoiceGlow",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Same sources as voice-glow's VoiceGlowKit, product renamed so it
        // does not collide with Libraries.dev. Mac Catalyst needs the
        // AVFAudio import added in VoiceMeter.swift.
        .library(name: "BankVoiceGlow", targets: ["BankVoiceGlow"]),
    ],
    targets: [
        .target(
            name: "BankVoiceGlow",
            path: "Sources/VoiceGlowKit",
            resources: [
                .process("VoiceGlowShaders.metal"),
            ]
        ),
    ]
)
