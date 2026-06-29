import SwiftUI

struct SectionLabel: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundStyle(AppTheme.inkSecondary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Label {
                        Text(LocalizedStringKey(actionTitle))
                    } icon: {
                        Image(systemName: "chevron.right")
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.primary)
            }
        }
    }
}

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(value)
                .font(.title2.weight(.bold))
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String = "arrow.right"
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(LocalizedStringKey(title))
            } icon: {
                Image(systemName: systemImage)
            }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(disabled ? AppTheme.inkSecondary.opacity(0.35) : AppTheme.primary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(LocalizedStringKey(title))
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String = "chevron.left"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(LocalizedStringKey(title))
            } icon: {
                Image(systemName: systemImage)
            }
                .font(.headline.weight(.bold))
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .foregroundStyle(AppTheme.primary)
                .background(AppTheme.lavender.opacity(0.8), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var buttonIcon: String = "plus"
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 96, height: 96)
                .background(AppTheme.lavender, in: Circle())

            VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.title3.weight(.bold))
                Text(LocalizedStringKey(message))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.inkSecondary)
            }

            if let buttonTitle, let action {
                Button(action: action) {
                    Label {
                        Text(LocalizedStringKey(buttonTitle))
                    } icon: {
                        Image(systemName: buttonIcon)
                    }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 13)
                        .padding(.horizontal, 24)
                        .background(AppTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassPanel(padding: 20)
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.inkSecondary)
            TextField(LocalizedStringKey(placeholder), text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .font(.headline)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var trailing: String?
    var locked = false
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(locked ? AppTheme.inkSecondary : AppTheme.primary)
                    .frame(width: 42, height: 42)
                    .background((locked ? AppTheme.inkSecondary : AppTheme.primary).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title))
                        .font(.headline.weight(.semibold))
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.inkSecondary)
                    }
                }

                Spacer()

                if let trailing {
                    Text(trailing)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.inkSecondary)
                }

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
