import AppKit
import SwiftUI

/// One palette, type scale and spacing rhythm for the window, onboarding and live card.
enum KeptTheme {
    static let radius: CGFloat = 16
    static let inset: CGFloat = 20
    static let gutter: CGFloat = 20
    static let margin: CGFloat = 36
    static let animation = Animation.snappy(duration: 0.22)
}

enum KeptType {
    static let page = Font.system(size: 30, weight: .semibold)
    static let title = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 14)
    static let secondary = Font.system(size: 13)
    static let caption = Font.system(size: 11)
    static let eyebrow = Font.system(size: 10, weight: .semibold, design: .rounded)
}

enum KeptColor {
    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static let canvasNS = dynamic(
        light: NSColor(calibratedRed: 0.973, green: 0.965, blue: 0.950, alpha: 1),
        dark: NSColor(calibratedRed: 0.100, green: 0.102, blue: 0.124, alpha: 1)
    )
    static let canvas = Color(nsColor: canvasNS)
    static let rail = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.932, green: 0.918, blue: 0.895, alpha: 1),
        dark: NSColor(calibratedRed: 0.131, green: 0.130, blue: 0.153, alpha: 1)
    ))
    static let card = Color(nsColor: dynamic(
        light: .white,
        dark: NSColor(calibratedRed: 0.168, green: 0.168, blue: 0.197, alpha: 1)
    ))
    static let field = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.967, green: 0.958, blue: 0.940, alpha: 1),
        dark: NSColor(calibratedRed: 0.130, green: 0.130, blue: 0.153, alpha: 1)
    ))
    static let accent = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.416, green: 0.286, blue: 0.646, alpha: 1),
        dark: NSColor(calibratedRed: 0.715, green: 0.602, blue: 0.916, alpha: 1)
    ))
    static let onAccent = Color(nsColor: dynamic(
        light: .white,
        dark: NSColor(calibratedRed: 0.100, green: 0.102, blue: 0.124, alpha: 1)
    ))
    static let selected = accent.opacity(0.12)
    static let tint = accent.opacity(0.09)
    static let border = Color.primary.opacity(0.09)
}

struct KeptCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(KeptTheme.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KeptColor.card, in: RoundedRectangle(cornerRadius: KeptTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KeptTheme.radius, style: .continuous)
                    .strokeBorder(KeptColor.border, lineWidth: 1)
            }
    }
}

struct KeptPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(KeptColor.accent.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(KeptColor.onAccent)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

struct KeptSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(KeptType.eyebrow)
            .tracking(1.2)
            .foregroundStyle(KeptColor.accent)
    }
}
