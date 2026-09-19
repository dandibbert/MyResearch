import SwiftUI
import UIKit

enum ResearchStyle {
    static let accent = Color(hex: "5265DE")
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0x5265DE
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

struct TargetIcon: View {
    var target: SearchTarget
    var size: CGFloat = 34
    var body: some View {
        Image(systemName: UIImage(systemName: target.symbol) == nil ? "magnifyingglass" : target.symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(Color(hex: target.tintHex))
            .frame(width: size, height: size)
            .background(Color(hex: target.tintHex).opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

struct SourceRow: View {
    var target: SearchTarget
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            TargetIcon(target: target)
            VStack(alignment: .leading, spacing: 3) {
                Text(target.name).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 4)
            if let alias = target.aliases.first {
                Text(alias).font(.caption.monospaced()).lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .foregroundStyle(.secondary).background(.quaternary, in: Capsule())
            }
            Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 48).contentShape(Rectangle())
    }
}
