import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Cross-platform UI helpers: semantic surfaces, adaptive layout for iPhone,
/// iPad, and Mac (Designed for iPad / Catalyst).
enum PlatformUI {
    /// Comfortable max content width on wide Mac / iPad windows.
    static let contentMaxWidth: CGFloat = 720
    /// Wider max for multi-column dashboard areas.
    static let dashboardMaxWidth: CGFloat = 980
    /// Preferred minimum window size on macOS.
    static let macMinWidth: CGFloat = 900
    static let macMinHeight: CGFloat = 620

    static var isMac: Bool {
        #if os(macOS)
        return true
        #elseif targetEnvironment(macCatalyst)
        return true
        #elseif canImport(UIKit)
        return ProcessInfo.processInfo.isiOSAppOnMac
        #else
        return false
        #endif
    }

    static var usesPointerInput: Bool { isMac }
}

// MARK: - Semantic surfaces (SwiftUI-first; UIKit only for adaptive Color)

extension Color {
    /// Primary canvas behind lists / forms.
    static var bankBackground: Color {
        adaptive(
            light: Color(red: 0.96, green: 0.97, blue: 0.99),
            dark: Color(red: 0.06, green: 0.07, blue: 0.10)
        )
    }

    /// Grouped / inset field fill.
    static var bankGroupedBackground: Color {
        adaptive(
            light: Color(red: 0.93, green: 0.94, blue: 0.96),
            dark: Color(red: 0.11, green: 0.12, blue: 0.15)
        )
    }

    /// Elevated card surface when material is unavailable.
    static var bankCardBackground: Color {
        adaptive(
            light: .white,
            dark: Color(red: 0.12, green: 0.13, blue: 0.16)
        )
    }

    /// Subtle hairline / divider.
    static var bankSeparator: Color {
        Color.primary.opacity(0.08)
    }

    /// Brand gradient for hero fills (buttons, badges).
    static var bankPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.bankPrimary,
                Color.bankPrimary.opacity(0.85),
                Color(red: 0.32, green: 0.42, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft ambient wash for login / splash.
    static var bankAmbientGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.bankPrimary.opacity(0.12),
                Color.bankSecondary.opacity(0.08),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return light
        #endif
    }
}

// MARK: - Adaptive layout modifiers

struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var maxWidth: CGFloat = PlatformUI.contentMaxWidth

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

struct ScreenPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.padding(.horizontal, sizeClass == .regular ? AppSpacing.xxl : AppSpacing.lg)
    }
}

extension View {
    /// Centers content and caps width on regular size classes (iPad / Mac).
    func adaptiveContentWidth(_ maxWidth: CGFloat = PlatformUI.contentMaxWidth) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }

    /// Horizontal padding that scales up on wide layouts.
    func screenPadding() -> some View {
        modifier(ScreenPadding())
    }

    /// Inline title style when supported.
    @ViewBuilder
    func bankInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Hover affordance for pointer platforms (Mac).
    func bankHoverHighlight(_ radius: CGFloat = AppTheme.CornerRadius.medium) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: radius))
    }

    /// Soft fade at every scroll edge (iOS 26 `scrollEdgeEffectStyle`).
    func bankSoftScrollEdges() -> some View {
        scrollEdgeEffectStyle(.soft, for: .all)
    }

    /// Applies `.searchable` only when `enabled` is true. Use this when a
    /// view might be presented standalone (wants its own search field) or
    /// embedded inside a parent that already provides one — SwiftUI only
    /// honors the outermost `.searchable` in a navigation stack, so a
    /// second one is silently dropped and just adds confusion.
    @ViewBuilder
    func searchableIf(_ enabled: Bool, text: Binding<String>, prompt: String) -> some View {
        if enabled {
            self.searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}

private struct HoverHighlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Keyboard / focus helpers

enum KeyboardDismiss {
    static func resign() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
    }
}
