import SwiftUI

/// Drafts never touch scene history. Only a valid Return commits; Escape restores the current value.
public struct NumericDraft: Equatable, Sendable {
    public private(set) var text: String
    public private(set) var isInvalid = false
    public mutating func replace(_ text: String) { self.text = text; isInvalid = false }
    public mutating func cancel(_ currentValue: String) { text = currentValue; isInvalid = false }
    public mutating func commit(in range: ClosedRange<Double>, integer: Bool = false, locale: Locale = .current) -> Double? {
        let number = value(in: range, integer: integer, locale: locale)
        isInvalid = number == nil
        return number
    }
    public init(_ text: String) { self.text = text }
    public func value(in range: ClosedRange<Double>, integer: Bool = false, locale: Locale = .current) -> Double? {
        // NumberFormatter accepts trailing garbage on some platforms. Parse the entire string.
        let separator = locale.decimalSeparator ?? "."
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty, normalized.allSatisfy({ "+-0123456789.eE".contains($0) }),
              let value = Double(normalized), value.isFinite, range.contains(value), !integer || value.rounded() == value else { return nil }
        return value
    }
}
public struct NumericParameter: View {
    let state: KitState?
    let title: String
    let unit: String
    let value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let digits: Int
    let integer: Bool
    let change: (Double) -> Void
    let exactChange: (Double) -> Void
    let beginEdit: () -> Void
    let endEdit: () -> Void
    @State private var probeID = UUID().uuidString
    @State private var draft = NumericDraft("")
    private var invalid: Bool { draft.isInvalid }
    @State private var dragging = false
    @FocusState private var focused: Bool
    public init(_ title: String, unit: String = "", value: Double, range: ClosedRange<Double>, defaultValue: Double, digits: Int = 2, integer: Bool = false, state: KitState? = nil,
                change: @escaping (Double) -> Void, exactChange: ((Double) -> Void)? = nil, beginEdit: @escaping () -> Void, endEdit: @escaping () -> Void) {
        self.state = state
        self.title = title; self.unit = unit; self.value = value; self.range = range; self.defaultValue = defaultValue
        self.exactChange = exactChange ?? change
        self.digits = digits; self.integer = integer; self.change = change; self.beginEdit = beginEdit; self.endEdit = endEdit
    }
    private var formatted: String { value.formatted(.number.grouping(.never).precision(.fractionLength(digits))) }
    public var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(title).font(KitType.label).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.xs)
                TextField(title, text: Binding(get: { focused || invalid ? draft.text : formatted }, set: { draft.replace($0) }))
                    .font(KitType.value).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
                    .frame(width: Metric.valueWidth).focused($focused)
                    .accessibilityLabel(title).accessibilityValue("\(formatted) \(unit)")
                    .help("Enter \(range.lowerBound.formatted()) through \(range.upperBound.formatted()) \(unit). Return commits; Escape cancels.")
                    .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(invalid || state == .error ? Ink.error : state == .focused ? Ink.accent : Color.clear))
                    .onSubmit { commit() }
                    .onExitCommand { cancel() }
                    .onChange(of: focused) { _, now in if now && !invalid { draft.cancel(formatted) } }
                if !unit.isEmpty { Text(unit).font(KitType.meta).foregroundStyle(Ink.secondary) }
            }
            .frame(minHeight: Metric.control)
            .gridProbe(probeID+"-label", area: probeID+"-parameter")
            if invalid || state == .error { Text("Enter a value from \(range.lowerBound.formatted()) to \(range.upperBound.formatted())\(integer ? " (whole numbers)" : "").").font(KitType.meta).foregroundStyle(Ink.error).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Invalid \(title)").frame(minHeight: Space.xl).gridProbe(probeID+"-error", area: probeID+"-parameter") }
            if !integer {
                Slider(value: Binding(get: { value }, set: { change($0) }), in: range, step: pow(10, -Double(digits)), onEditingChanged: { editing in if editing { dragging = true; beginEdit() } else { finishContinuous() } })
                    .accessibilityLabel(title).accessibilityValue("\(formatted) \(unit)")
                    .frame(minHeight: Space.xxl)
                    .gridProbe(probeID+"-slider", area: probeID+"-parameter")
                    .overlay(alignment: .center) {
                        if range.lowerBound < 0 && range.upperBound == -range.lowerBound { Rectangle().fill(Ink.border).frame(width: 1, height: Space.sm).allowsHitTesting(false) }
                    }
            }
        }.gridArea(probeID+"-parameter", inset: 0).disabled(state == .disabled).frame(minHeight: integer ? Metric.control : Metric.parameter)
            .contextMenu { Button("Reset \(title)") { finishContinuous(); exactChange(defaultValue); cancel() } }
            .onDisappear { finishContinuous() }
    }
    private func commit() {
        guard let number = draft.commit(in: range, integer: integer) else { return }
        finishContinuous(); exactChange(number); focused = false
    }
    private func finishContinuous() { if dragging { dragging = false; endEdit() } }
    private func cancel() { draft.cancel(formatted); focused = false }
}
