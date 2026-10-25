import SwiftUI

/// Toy-diorama colors, type, and spacing from docs/ART_DIRECTION.md.
/// A later UI style sheet should replace this file rather than scatter new values.
enum RepublicTheme {
    static let sea = Color(red: 14 / 255, green: 94 / 255, blue: 140 / 255)
    static let turquoise = Color(red: 0, green: 194 / 255, blue: 238 / 255)
    static let sand = Color(red: 232 / 255, green: 199 / 255, blue: 122 / 255)
    static let grass = Color(red: 93 / 255, green: 170 / 255, blue: 69 / 255)
    static let fertile = Color(red: 62 / 255, green: 130 / 255, blue: 54 / 255)
    static let rock = Color(red: 124 / 255, green: 128 / 255, blue: 124 / 255)
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
        static let xl: CGFloat = 24
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

struct TerracottaButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RepublicTheme.heading(.body))
            .foregroundStyle(RepublicTheme.cream)
            .multilineTextAlignment(.center)
            .padding(.horizontal, RepublicTheme.Space.md)
            .padding(.vertical, RepublicTheme.Space.sm)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RepublicTheme.terracotta.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35),
                in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous)
            )
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RepublicTheme.body(.body))
            .foregroundStyle(RepublicTheme.inkSoft.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}
