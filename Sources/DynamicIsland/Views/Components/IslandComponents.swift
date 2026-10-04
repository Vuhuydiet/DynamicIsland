import SwiftUI
import AppKit

// MARK: - Standard Button Styles & Variants

public enum IslandButtonVariant {
    case primary(Color = .blue)
    case secondary
    case ghost
    case tinted(Color)
    case danger
}

public enum IslandButtonSize {
    case small
    case regular
    case large
    
    public var height: CGFloat {
        switch self {
        case .small: return 24
        case .regular: return 28
        case .large: return 34
        }
    }
    
    public var horizontalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .regular: return 12
        case .large: return 16
        }
    }
    
    public var font: Font {
        switch self {
        case .small: return IslandFont.micro
        case .regular: return IslandFont.caption
        case .large: return IslandFont.subtitle
        }
    }
    
    public var iconFont: Font {
        switch self {
        case .small: return IslandFont.iconMicro
        case .regular: return IslandFont.iconSmall
        case .large: return IslandFont.iconRegular
        }
    }
}

/// Standardized tactile button for tabs, tools, and plugins.
public struct IslandButton: View {
    public var title: String?
    public var icon: String?
    public var variant: IslandButtonVariant
    public var size: IslandButtonSize
    public var action: () -> Void
    
    public init(
        _ title: String? = nil,
        icon: String? = nil,
        variant: IslandButtonVariant = .secondary,
        size: IslandButtonSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            SoundManager.shared.play(.click)
            action()
        }) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                if let title = title {
                    Text(title)
                        .font(size.font)
                        .lineLimit(1)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay(strokeOverlay)
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary(let color):
            return color == .white ? .black : .white
        case .secondary:
            return .white.opacity(0.85)
        case .ghost:
            return .white.opacity(0.65)
        case .tinted(let color):
            return color
        case .danger:
            return .red
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary(let color):
            color
        case .secondary:
            Color.white.opacity(0.12)
        case .ghost:
            Color.white.opacity(0.04)
        case .tinted(let color):
            color.opacity(0.18)
        case .danger:
            Color.red.opacity(0.16)
        }
    }
    
    @ViewBuilder
    private var strokeOverlay: some View {
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        case .ghost:
            EmptyView()
        case .tinted(let color):
            Capsule().stroke(color.opacity(0.30), lineWidth: 0.5)
        case .danger:
            Capsule().stroke(Color.red.opacity(0.30), lineWidth: 0.5)
        }
    }
}

// MARK: - Standardized Header Component

/// A standardized header for all tool views and injected plugins.
public struct IslandHeaderView<Trailing: View>: View {
    public var icon: String?
    public var iconColor: Color
    public var iconView: AnyView?
    public var title: String
    public var subtitle: String?
    public var statusBadge: String?
    public var statusColor: Color
    public var trailing: Trailing
    
    public init(
        icon: String? = nil,
        iconColor: Color = .blue,
        iconView: AnyView? = nil,
        title: String,
        subtitle: String? = nil,
        statusBadge: String? = nil,
        statusColor: Color = .green,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconView = iconView
        self.title = title
        self.subtitle = subtitle
        self.statusBadge = statusBadge
        self.statusColor = statusColor
        self.trailing = trailing()
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Leading: Icon + Titles + Optional Badge
            HStack(spacing: 6) {
                if let iconView = iconView {
                    iconView
                        .frame(width: 18, height: 18)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(IslandFont.iconRegular)
                        .foregroundColor(iconColor)
                        .frame(width: 18, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(IslandFont.title)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let status = statusBadge {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 5, height: 5)
                                Text(status)
                                    .font(IslandFont.micro)
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(IslandFont.micro)
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Trailing actions
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }
}

public extension IslandHeaderView where Trailing == EmptyView {
    init(
        icon: String? = nil,
        iconColor: Color = .blue,
        title: String,
        subtitle: String? = nil,
        statusBadge: String? = nil,
        statusColor: Color = .green
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            statusBadge: statusBadge,
            statusColor: statusColor,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Standardized Card / Surface Container

/// Standard Liquid Glass card container for grouping content inside tabs.
public struct IslandCardView<Content: View>: View {
    public var cornerRadius: CGFloat
    public var content: Content
    
    public init(cornerRadius: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Standardized Translucent Divider

/// Subtle translucent separator line unifying the glass divider across tools.
public struct IslandDivider: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.20))
                .frame(height: 0.5)
                .offset(y: 0.5)
        }
    }
}

// MARK: - Standardized Search Field

/// Standard text input / search field with icon and clear button.
public struct IslandSearchField: View {
    @Binding public var text: String
    public var placeholder: String
    public var onCommit: (() -> Void)?
    
    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.40))
                .font(IslandFont.iconRegular)
            
            TextField(placeholder, text: $text, onCommit: {
                onCommit?()
            })
            .textFieldStyle(.plain)
            .font(IslandFont.body)
            .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation(IslandSpring.bouncy) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.45))
                        .font(IslandFont.iconRegular)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
    }
}

// MARK: - Standardized Empty State View

/// Clean empty state placeholder for tabs or plugins when offline/empty.
public struct IslandEmptyStateView: View {
    public var icon: String
    public var title: String
    public var subtitle: String?
    public var actionTitle: String?
    public var action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.35))
            
            Text(title)
                .font(IslandFont.subtitle)
                .foregroundColor(.white.opacity(0.70))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if let actionTitle = actionTitle, let action = action {
                IslandButton(actionTitle, variant: .secondary, size: .small, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

