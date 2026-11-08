import SwiftUI

/// Toy-diorama colors and type from `docs/ART_DIRECTION.md` and `docs/art/UI_STYLE.md`.
/// Presentation only. The simulation does not read these values.
enum RepublicTheme {
    static let panel = Color(red: 0.075, green: 0.105, blue: 0.10)
    static let brass = Color(red: 0.85, green: 0.72, blue: 0.43)
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.85)
    static let sea = Color(red: 14 / 255, green: 94 / 255, blue: 140 / 255)
    static let turquoise = Color(red: 0, green: 194 / 255, blue: 238 / 255)
    static let sand = Color(red: 232 / 255, green: 199 / 255, blue: 122 / 255)
    static let grass = Color(red: 93 / 255, green: 170 / 255, blue: 69 / 255)
    static let fertile = Color(red: 62 / 255, green: 130 / 255, blue: 54 / 255)
    static let terracotta = Color(red: 210 / 255, green: 85 / 255, blue: 46 / 255)
    static let cream = Color(red: 244 / 255, green: 235 / 255, blue: 221 / 255)
    static let alert = Color(red: 242 / 255, green: 98 / 255, blue: 42 / 255)
    static let ink = Color(red: 58 / 255, green: 42 / 255, blue: 34 / 255)
    static let inkSoft = Color(red: 107 / 255, green: 83 / 255, blue: 70 / 255)
    static let pastels: [Color] = [
        Color(red: 242 / 255, green: 184 / 255, blue: 198 / 255),
        Color(red: 245 / 255, green: 213 / 255, blue: 138 / 255),
        Color(red: 169 / 255, green: 216 / 255, blue: 200 / 255),
        Color(red: 242 / 255, green: 164 / 255, blue: 122 / 255)
    ]

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let radius: CGFloat = 18
        static let chip: CGFloat = 12
    }

    static func heading(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }

    static func body(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .default)
    }
}

struct DioramaCard: ViewModifier {
    var fill: Color = RepublicTheme.cream

    func body(content: Content) -> some View {
        content
            .padding(RepublicTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: RepublicTheme.Space.radius, style: .continuous))
            .foregroundStyle(RepublicTheme.ink)
    }
}

extension View {
    func dioramaCard(fill: Color = RepublicTheme.cream) -> some View {
        modifier(DioramaCard(fill: fill))
    }
}

/// Deliberately restrained game chrome. Selection is a border and a warm fill,
/// with the same readable 44-point target in either display posture.
struct RepublicDockButton: ButtonStyle {
    var selected = false
    var primary = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(primary ? RepublicTheme.panel : (selected ? RepublicTheme.brass : RepublicTheme.paper))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(primary ? RepublicTheme.brass : RepublicTheme.paper.opacity(selected ? 0.12 : 0.045),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? RepublicTheme.brass.opacity(0.8) : RepublicTheme.paper.opacity(0.12), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
