import SwiftUI

enum AppTheme {
    static let brandName = "Quantaflow"
    static let backgroundTop = Color(uiColor: .systemBackground)
    static let backgroundBottom = Color(uiColor: .secondarySystemBackground)
    static let primary = Color(hex: 0x5145F6)
    static let primaryDeep = Color(hex: 0x23215B)
    static let lavender = Color(hex: 0xE8E4FF)
    static let mint = Color(hex: 0xCFF7E6)
    static let peach = Color(hex: 0xFFD9D2)
    static let butter = Color(hex: 0xFFE9A8)
    static let blue = Color(hex: 0x2D7FF9)
    static let green = Color(hex: 0x22C55E)
    static let orange = Color(hex: 0xF59E0B)
    static let red = Color(hex: 0xEF4444)
    static let ink = Color.primary
    static let inkSecondary = Color.secondary
    static let stroke = Color.primary.opacity(0.12)
    static let card = Color(uiColor: .secondarySystemBackground).opacity(0.78)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct AppBackground<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: 0x10182F), Color(hex: 0x23312C)]
                    : [Color(hex: 0xF8FBFF), Color(hex: 0xEEF7F2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppTheme.primary.opacity(colorScheme == .dark ? 0.20 : 0.10),
                    AppTheme.mint.opacity(colorScheme == .dark ? 0.16 : 0.18),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .tint(AppTheme.primary)
        .foregroundStyle(AppTheme.ink)
    }
}

struct GlassPanel: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: AppTheme.primaryDeep.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func glassPanel(padding: CGFloat = 16) -> some View {
        modifier(GlassPanel(padding: padding))
    }
}
