import SwiftUI
import VHSCore

struct ControlView: View {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: Space.section) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .gridProbe("preview-column", area: "page", edge: nil)
            Divider()
            parameters.frame(width: Layout.controlWidth)
                .gridProbe("parameters-column", area: "page", edge: nil)
        }
        .padding(Space.margin)
        .gridArea("page")
        .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
        .background(.background)
        .overlay { if GridOverlay.enabled { GridOverlay() } }
        .navigationTitle("Untitled Scene")
        .task {
            model.start()
            try? await Task.sleep(for: .milliseconds(100))
            model.commands.install(showControl: { openWindow(id: "control") })
            await Verification.runIfRequested(model: model)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Show Output", systemImage: "rectangle.on.rectangle") { model.output.show() }
                    .help("Open the performance output window (Command-Shift-O)")
            }
        }
    }
    private var preview: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Live Preview").font(.headline).gridProbe("preview-title", area: "preview")
            Group {
                if let error = model.errorMessage {
                    ContentUnavailableView("Unable to Render", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    MetalSurface(model: model)
                        .accessibilityLabel("Live preview of solid color")
                }
            }
            .aspectRatio(16.0 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Layout.previewRadius))
            .gridProbe("preview-surface", area: "preview")
            Label("Solid", systemImage: "square.fill")
                .font(.subheadline).foregroundStyle(.secondary)
                .gridProbe("preview-source", area: "preview")
            Spacer(minLength: 0)
        }
        .gridArea("preview", inset: 0)
    }
    private var parameters: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Source").font(.headline)
                Label("Solid", systemImage: "square.fill").font(.title2)
                Text("Fill the scene with a single color.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.gridProbe("source-heading", area: "parameters")
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Color").font(.headline).gridProbe("color-heading", area: "color")
                ForEach(ParameterID.allCases, id: \.self) { id in
                    ChannelControl(model: model, id: id)
                        .gridProbe(id.rawValue, area: "color")
                }
            }.gridArea("color", inset: 0)
                .gridProbe("color-controls", area: "parameters")
            Text("Adjust the color here while the output stays live.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("source-help", area: "parameters")
        }.gridArea("parameters", inset: 0)
    }
}

private struct ChannelControl: View {
    let model: AppModel
    let id: ParameterID
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(id.title)
                Spacer()
                Text(model.scene.color[id], format: .number.precision(.fractionLength(2)))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .gridProbe(id.rawValue + "-label", area: id.rawValue + "-area")
            Slider(value: Binding(get: { model.scene.color[id] }, set: { model.send(.setParameter(id, $0)) }),
                   in: 0...1, onEditingChanged: { editing in
                if editing { model.beginEdit() } else { model.endEdit() }
            })
            .accessibilityLabel("\(id.title) color component")
            .accessibilityValue(model.scene.color[id].formatted(.number.precision(.fractionLength(2))))
            .help("Set the linear \(id.title.lowercased()) component from 0 to 1")
            .gridProbe(id.rawValue + "-slider", area: id.rawValue + "-area")
        }
        .gridArea(id.rawValue + "-area", inset: 0)
    }
}
