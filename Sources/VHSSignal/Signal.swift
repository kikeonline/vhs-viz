import AppKit
import SwiftUI

/// The approved specification supplies runtime values, rather than a second hand-maintained palette.
enum SignalSpecification {
    static let values = try! JSONSerialization.jsonObject(with: Data(contentsOf: SignalResources.tokens)) as! [String: Any]
    static func number(_ group: String, _ key: String) -> CGFloat { (values[group] as! [String: NSNumber])[key]!.doubleValue }
    static func size(_ role: String) -> CGFloat { ((values["type"] as! [String: [String: Any]])[role]!["size"] as! NSNumber).doubleValue }
}
public enum Ink {
    private static let themes = SignalSpecification.values["themes"] as! [String: [String: String]]
    public static func color(_ role: String) -> Color {
        let values = themes
        return Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.accessibilityHighContrastDarkAqua, .accessibilityHighContrastAqua, .darkAqua, .aqua])
            let theme: String
            switch match {
            case .accessibilityHighContrastDarkAqua: theme = "darkHighContrast"
            case .accessibilityHighContrastAqua: theme = "lightHighContrast"
            case .darkAqua: theme = "dark"
            default: theme = "light"
            }
            let hex = values[theme]![role]!
            let rgb = UInt32(hex.dropFirst(), radix: 16)!
            return NSColor(srgbRed: Double((rgb >> 16) & 255)/255, green: Double((rgb >> 8) & 255)/255, blue: Double(rgb & 255)/255, alpha: 1)
        })
    }
    public static var canvas: Color { color("canvas") }
    public static var warning: Color { color("warning") }
    public static var surface: Color { color("surface") }
    public static var raised: Color { color("raised") }
    public static var hover: Color { color("hover") }
    public static var text: Color { color("text") }
    public static var secondary: Color { color("secondary") }
    public static var muted: Color { color("muted") }
    public static var divider: Color { color("divider") }
    public static var border: Color { color("controlBorder") }
    public static var selection: Color { color("selection") }
    public static var error: Color { color("error") }
    public static var accent: Color {
        let brand = NSColor(color("accent"))
        return Color(nsColor: NSColor(name: nil) { appearance in
            if let choice = UserDefaults.standard.object(forKey: "AppleAccentColor") as? Int, choice != -1 { return .controlAccentColor }
            var resolved = brand
            appearance.performAsCurrentDrawingAppearance { resolved = brand.usingColorSpace(.sRGB) ?? brand }
            return resolved
        })
    }
}
public enum Radius {
    public static let control = SignalSpecification.number("radius", "control")
    public static let panel = SignalSpecification.number("radius", "panel")
}
public enum Metric {
    public static let control = SignalSpecification.number("metric", "controlHeight")
    public static let row = SignalSpecification.number("metric", "chainRowHeight")
    public static let parameter = SignalSpecification.number("metric", "parameterHeight")
    public static let valueWidth: CGFloat = 88
    public static let focus = SignalSpecification.number("metric", "focusWidth")
}
public enum KitType {
    public static let title = Font.system(size: SignalSpecification.size("title"), weight: .semibold)
    public static let section = Font.system(size: SignalSpecification.size("section"), weight: .semibold)
    public static let body = Font.system(size: SignalSpecification.size("body"))
    public static let label = Font.system(size: SignalSpecification.size("label"), weight: .medium)
    public static let meta = Font.system(size: SignalSpecification.size("meta"))
    public static let value = Font.system(size: SignalSpecification.size("value"), weight: .medium).monospacedDigit()
}
public enum KitIcon: String {
    case source = "waveform", effects = "slider.horizontal.3", graph = "point.3.connected.trianglepath.dotted"
    case output = "rectangle.on.rectangle", bypass = "power", warning = "exclamationmark.triangle"
    case error = "exclamationmark.circle", add = "plus", up = "chevron.up", down = "chevron.down"
    case imagePort = "square.fill", scalarPort = "circle.fill", vectorPort = "diamond.fill"
    case duplicate = "plus.square.on.square", remove = "trash", zoomOut = "minus.magnifyingglass", zoomIn = "plus.magnifyingglass"
}
public enum Motion {
    public static func hover(reduce: Bool) -> Animation? { reduce ? nil : .easeOut(duration: 0.08) }
    public static func disclosure(reduce: Bool) -> Animation? { reduce ? nil : .easeOut(duration: 0.12) }
}
public enum KitState: String, CaseIterable, Identifiable {
    case rest, hover, pressed, selected, focused, disabled, inactive, error, bypassed
    public var id: String { rawValue }
}
public struct SignalButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    @Environment(\.appearsActive) private var active
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    private let forced: KitState?
    public init(state: KitState? = nil) { forced = state }
    public func makeBody(configuration: Configuration) -> some View {
        let disabled = !enabled || forced == .disabled
        let pressed = configuration.isPressed || forced == .pressed
        return configuration.label.font(KitType.label)
            .padding(.horizontal, Space.md).frame(minHeight: Metric.control)
            .foregroundStyle(disabled ? Ink.muted : Ink.text)
            .background(disabled || !active || forced == .inactive ? Ink.surface : pressed ? Ink.selection : hovering || forced == .hover ? Ink.hover : Ink.raised, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(forced == .error ? Ink.error : forced == .selected ? Ink.accent : Ink.border))
            .overlay { if focused || forced == .focused { RoundedRectangle(cornerRadius: Radius.control).stroke(Ink.accent, lineWidth: Metric.focus).padding(-Metric.focus) } }
            .onHover { hovering = $0 }.animation(Motion.hover(reduce: reduceMotion), value: hovering)
    }
}
private struct SignalTheme: ViewModifier {
    @Environment(\.legibilityWeight) private var legibility
    func body(content: Content) -> some View {
        content.font(KitType.body).fontWeight(legibility == .bold ? .bold : nil)
            .foregroundStyle(Ink.text).tint(Ink.accent).buttonStyle(SignalButtonStyle()).background(Ink.canvas)
    }
}
public extension View {
    func signalTheme() -> some View { modifier(SignalTheme()) }
}

private struct SignalRow: ViewModifier {
    let selected: Bool
    let forced: KitState?
    @Environment(\.appearsActive) private var active
    @State private var hovering = false
    func body(content: Content) -> some View {
        content.frame(minHeight: Metric.row)
            .padding(.horizontal, Space.sm)
            .background(selected || forced == .selected ? Ink.selection : hovering || forced == .hover ? Ink.hover : Ink.surface)
            .overlay(alignment: .leading) {
                if selected || forced == .selected { Rectangle().fill(active && forced != .inactive ? Ink.accent : Ink.border).frame(width: Metric.focus) }
            }
            .onHover { hovering = $0 }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
public extension View {
    func signalRow(selected: Bool, state: KitState? = nil) -> some View { modifier(SignalRow(selected: selected, forced: state)) }
}

/// Actual native controls in reproducible states; never a production navigation tab.
public struct KitGallery: View {
    let states: [KitState]
    public init(states: [KitState] = KitState.allCases) { self.states = states }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("VHS / Signal").font(KitType.title).gridProbe("gallery-title", area: "gallery")
                Text("Native component states").font(KitType.section).gridProbe("gallery-subtitle", area: "gallery")
                ForEach(states) { state in
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(spacing: Space.lg) {
                            Text(state.rawValue.capitalized).font(KitType.section).frame(width: Metric.valueWidth, alignment: .leading)
                            Button("Show Output", systemImage: KitIcon.output.rawValue) {}.buttonStyle(SignalButtonStyle(state: state)).disabled(state == .disabled)
                            Toggle(state == .bypassed ? "Bypassed" : "Bypass", isOn: .constant(state == .bypassed || state == .selected)).toggleStyle(.checkbox).disabled(state == .disabled)
                        }
                        HStack(spacing: Space.lg) {
                            Text("1").font(KitType.value).strikethrough(state == .bypassed)
                            Text("Colorize").font(KitType.label)
                            if state == .bypassed { Text("Bypassed").font(KitType.meta) }
                            Spacer()
                            Text("Image ■").font(KitType.meta).foregroundStyle(Ink.color("image"))
                        }.signalRow(selected: state == .selected || state == .inactive, state: state)
                        NumericParameter("Position", unit: "pt", value: 0, range: -1...1, defaultValue: 0, state: state, change: { _ in }, beginEdit: {}, endEdit: {})
                            .frame(width: Layout.controlWidth)
                    }.padding(Space.lg).gridArea("gallery-"+state.rawValue, inset: Space.lg).gridProbe("gallery-"+state.rawValue, area: "gallery").background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.panel))
                }
                HStack(spacing: Space.lg) {
                    ColorPicker("Scene color", selection: .constant(.purple), supportsOpacity: false)
                    Picker("Source", selection: .constant(0)) { Text("Solid").tag(0); Text("Gradient").tag(1) }
                }.frame(width: Layout.sheetWidth)
                Text("Image ■ · Scalar ● · Vector ◆ · Color ◆").font(KitType.meta)
            }.padding(Space.margin).gridArea("gallery").frame(maxWidth: .infinity, alignment: .leading)
        }.signalTheme()
    }
}

/// Compact native node buttons keep their port geometry and expose hover, press and keyboard focus.
public struct SignalCanvasButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(enabled ? Ink.text : Ink.muted)
            .background(configuration.isPressed ? Ink.selection : hovering ? Ink.hover : Color.clear)
            .overlay { if focused { RoundedRectangle(cornerRadius: Radius.control).stroke(Ink.accent, lineWidth: Metric.focus) } }
            .onHover { hovering = $0 }
    }
}
