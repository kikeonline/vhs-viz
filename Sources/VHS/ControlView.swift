import SwiftUI
import VHSCore

struct ControlView: View {
    let model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: Space.section) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .gridProbe("preview-column", area: "page", edge: nil)
            Divider()
            SourceControls(model: model).frame(width: Layout.controlWidth)
                .disabled(model.files.blocksSceneEditing)
                .gridProbe("parameters-column", area: "page", edge: nil)
        }
        .padding(Space.margin)
        .gridArea("page")
        .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
        .background(.background)
        .overlay { if GridOverlay.enabled { GridOverlay() } }
        .navigationTitle(model.projectName)
        .background {
            ProjectWindow(model: model, title: model.projectName, fileURL: model.fileURL, isDirty: model.isDirty)
                .frame(width: 0, height: 0)
        }
        .sheet(isPresented: Binding(get: { model.files.isRenaming }, set: { model.files.isRenaming = $0 })) {
            RenameProjectView(model: model)
        }
        .task {
            model.start()
            Task { await Verification.runIfRequested(model: model) }
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
                        .accessibilityLabel("Live preview of \(model.scene.source.definition.title.lowercased())")
                }
            }
            .aspectRatio(16.0 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Layout.previewRadius))
            .gridProbe("preview-surface", area: "preview")
            HStack {
                Label(model.scene.source.definition.title, systemImage: model.scene.source.definition.symbol)
                Spacer()
                Text(model.isDirty ? "Edited" : (model.fileURL == nil ? "Not saved" : "Saved"))
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .gridProbe("preview-source", area: "preview")
            Spacer(minLength: 0)
        }
        .gridArea("preview", inset: 0)
    }
}
