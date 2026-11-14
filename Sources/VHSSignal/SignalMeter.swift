import SwiftUI

/// Shared semantic telemetry: no-data is distinct from measured zero. No implicit animation.
public struct SignalMeter: View {
    let title: String, reading: String
    let level: Double?
    public init(_ title: String, reading: String, level: Double?) {
        self.title = title; self.reading = reading
        self.level = level.map { $0.isFinite ? min(1, max(0, $0)) : 0 }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(title).font(KitType.label)
                Spacer()
                Text(reading).font(KitType.value).monospacedDigit()
            }
            GeometryReader { geometry in
                Rectangle().fill(Ink.raised)
                    .overlay(alignment: .leading) { Rectangle().fill(Ink.accent).frame(width: geometry.size.width * (level ?? 0)) }
                    .overlay(Rectangle().stroke(Ink.border))
            }.frame(height: Space.sm)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title).accessibilityValue(reading)
    }
}
