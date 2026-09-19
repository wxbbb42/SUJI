import SwiftUI
import UIKit

/// Paper and ink stay opaque; system materials are reserved for navigation and tools.
@MainActor @Observable final class SujiAppearance {
    var name = "system"
}

@MainActor enum SujiTheme {
    static let appearance = SujiAppearance()
    static func reduceMotion(_ system: Bool) -> Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-reduce-motion") { return true }
#endif
        return system
    }

    static func seasonalAccent(_ term: String) -> Color {
        if ["立夏", "小满", "芒种", "夏至", "小暑", "大暑"].contains(term) { return accent }
        if ["立秋", "处暑", "白露", "秋分", "寒露", "霜降"].contains(term) { return adaptive(light: 0x81633B, dark: 0xC7B386) }
        if ["立冬", "小雪", "大雪", "冬至", "小寒", "大寒"].contains(term) { return adaptive(light: 0x506F72, dark: 0xA3C4C8) }
        return sage
    }
    static var paper: Color { palette(light: 0xF6F3EC, dark: 0x181C19, celadon: 0xECF2EE, celadonDark: 0x15221F) }
    static var ink: Color { palette(light: 0x29352D, dark: 0xEDECE2, celadon: 0x243C35, celadonDark: 0xE6F0E9) }
    static var secondary: Color { palette(light: 0x6C7165, dark: 0xADB4A7, celadon: 0x5A7067, celadonDark: 0xAEC5B8) }
    static var accent: Color { palette(light: 0xA44735, dark: 0xDB947B, celadon: 0x326C5D, celadonDark: 0x9ED0B9) }
    static var line: Color { palette(light: 0xE1DFD4, dark: 0x3C463C, celadon: 0xC9DAD0, celadonDark: 0x38544A) }
    static var sage: Color { palette(light: 0x596C54, dark: 0xABBD9E, celadon: 0x4E7563, celadonDark: 0xABCDB9) }
    static var surface: Color { palette(light: 0xFFFDF8, dark: 0x242A24, celadon: 0xF7FAF7, celadonDark: 0x23362E) }

    private static func palette(light: UInt32, dark: UInt32, celadon: UInt32, celadonDark: UInt32) -> Color {
        let selected = appearance.name == "celadon"
        return adaptive(light: selected ? celadon : light, dark: selected ? celadonDark : dark)
    }

    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("NotoSerifSC-Regular", size: size, relativeTo: style)
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Original botanical art; display size belongs to each layout, never a screen capture.
struct SujiBotanical: View {
    var body: some View {
        Image("Ginkgo")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// A quiet, deterministic fibre pattern, rendered once rather than animated.
struct SujiPaperBackground: View {
    var color: Color = SujiTheme.paper

    var body: some View {
        color.overlay {
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                for index in 0..<360 {
                    let x = CGFloat((index * 127 + 19) % 997) / 997 * size.width
                    let y = CGFloat((index * 233 + 71) % 991) / 991 * size.height
                    var fibre = Path()
                    fibre.move(to: CGPoint(x: x, y: y))
                    fibre.addLine(to: CGPoint(x: x + CGFloat(index % 3 + 1), y: y + 0.3))
                    context.stroke(fibre, with: .color(SujiTheme.ink.opacity(0.032)), lineWidth: 0.45)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct SujiSeal: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SujiTheme.serif(14, relativeTo: .caption))
            .tracking(2)
            .foregroundStyle(SujiTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(SujiTheme.accent.opacity(0.82), lineWidth: 1)
            }
            .rotationEffect(.degrees(-2))
            .fixedSize()
    }
}

struct SujiQuietButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SujiTheme.reduceMotion(systemReduceMotion) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SujiTheme.ink)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(SujiTheme.ink.opacity(configuration.isPressed ? 0.09 : 0.035), in: Capsule())
            .overlay { Capsule().strokeBorder(SujiTheme.line, lineWidth: 0.75) }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
