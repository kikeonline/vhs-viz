import SwiftUI
import VHSCore
import VHSGraphUI

struct ControlView: View {
    let model: AppModel
    var body: some View {
        Group {
            if model.showsGraph { graphWorkspace }
            else { chainWorkspace }
        }
        .padding(Space.margin)
        .gridArea("page")
        .frame(minWidth: model.showsGraph ? Layout.graphMinWidth : Layout.minWidth,
               minHeight: model.showsGraph ? Layout.graphMinHeight : Layout.minHeight)
        .background(.background)
        .overlay { if GridOverlay.enabled { GridOverlay() } }
        .navigationTitle(model.projectName)
        .background {
            ProjectWindow(model: model, title: model.projectName, fileURL: model.fileURL, isDirty: model.isDirty).frame(width:0,height:0)
        }
        .sheet(isPresented: Binding(get: { model.files.isRenaming }, set: { model.files.isRenaming = $0 })) { RenameProjectView(model:model) }
        .task { model.start(); Task { await Verification.runIfRequested(model:model) } }
        .toolbar {
            ToolbarItem(placement:.primaryAction) {
                HStack(spacing:Space.sm) {
                    Button(model.showsGraph ? "Chain" : "Nodes",systemImage:"point.3.connected.trianglepath.dotted") { model.showsGraph.toggle() }
                        .disabled(model.showsGraph && !model.scene.canEditChain)
                        .help(model.showsGraph && !model.scene.canEditChain ? "This graph cannot be represented by the chain editor" : "Switch between compatible chain and node editors")
                    Button("Show Output",systemImage:"rectangle.on.rectangle") { model.output.show() }.help("Open the performance output window (Command-Shift-O)")
                }
            }
        }
    }
    private var graphWorkspace: some View {
        VStack(alignment:.leading,spacing:Space.lg) {
            HStack(alignment:.top,spacing:Space.lg) {
                MetalSurface(model:model).frame(width:Layout.graphPreviewWidth,height:Layout.graphPreviewWidth*9/16)
                    .clipShape(RoundedRectangle(cornerRadius:Layout.previewRadius))
                VStack(alignment:.leading,spacing:Space.sm) {
                    Text("Shader Graph").font(.headline)
                    Text(model.graphBuildMessage).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    if !model.scene.canEditChain { Text("Chain editing is unavailable for this graph; all nodes are preserved.").font(.caption).foregroundStyle(.secondary) }
                }
            }.gridProbe("graph-preview-status",area:"graph-window")
            GraphEditor(graph:model.scene.graph,layout:model.graphLayout,seed:model.scene.seed,state:model.graphEditor,send:model.send,setLayout:model.setGraphLayout,beginEdit:model.beginEdit,endEdit:model.endEdit)
                .disabled(model.files.blocksSceneEditing)
                .gridProbe("graph-editor",area:"graph-window")
        }.gridArea("graph-window",inset:0)
    }
    private var chainWorkspace: some View {
        HStack(alignment: .top, spacing: Space.section) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .gridProbe("preview-column", area: "page", edge: nil)
            Divider()
            Group {
                if let effect = model.selectedEffect { EffectControls(model: model, effect: effect) }
                else { SourceControls(model: model) }
            }.frame(width: Layout.controlWidth)
                .disabled(model.files.blocksSceneEditing)
                .gridProbe("parameters-column", area: "page", edge: nil)
        }
    }
    private var preview: some View {
        GeometryReader { geometry in
            let height = min(geometry.size.width * 9 / 16, max(0, geometry.size.height - Layout.previewReservedHeight))
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
                .frame(width: height * 16 / 9, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Layout.previewRadius))
                .gridProbe("preview-surface", area: "preview")
                HStack {
                    Label(model.scene.source.definition.title, systemImage: model.scene.source.definition.symbol)
                    Spacer()
                    Text(model.isDirty ? "Edited" : (model.fileURL == nil ? "Not saved" : "Saved"))
                }
                .font(.subheadline).foregroundStyle(.secondary)
                .gridProbe("preview-source", area: "preview")
                EffectChain(model: model)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .gridArea("preview", inset: 0)
    }
}
