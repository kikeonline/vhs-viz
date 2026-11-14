import SwiftUI
import VHSSignal
import VHSCore
import VHSGraphUI

struct ControlView: View {
    let model: AppModel
    var body: some View {
        Group {
            if ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1" { KitGallery() }
            else if model.showsGraph { graphWorkspace }
            else { chainWorkspace }
        }
        .padding(Space.margin)
        .gridArea("page")
        .frame(minWidth: model.showsGraph ? Layout.graphMinWidth : Layout.minWidth,
               minHeight: model.showsGraph ? Layout.graphMinHeight : Layout.minHeight)
        .signalTheme()
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
                    Picker("Editor", selection: Binding(get: { model.showsGraph }, set: { model.showsGraph = $0 })) {
                        Text("Chain").tag(false).disabled(!model.scene.canEditChain)
                        Text("Nodes").tag(true)
                    }.pickerStyle(.segmented).fixedSize()
                        .help("Switch between compatible chain and node editors")
                    Button("Inputs", systemImage: "waveform") { model.inputs.showsInputs.toggle() }
                        .help("Choose standalone audio and MIDI inputs and view live levels")
                        .popover(isPresented: Binding(get: { model.inputs.showsInputs }, set: { model.inputs.showsInputs = $0 })) {
                            InputsView(inputs: model.inputs)
                        }
                    Button("Show Output",systemImage: KitIcon.output.rawValue) { model.output.show() }.help("Open the performance output window (Command-Shift-O)")
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
                    Text("Shader Graph").font(KitType.section)
                    Text(model.graphBuildMessage).font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                    if !model.scene.canEditChain { Text("Chain editing is unavailable for this graph; all nodes are preserved.").font(KitType.meta).foregroundStyle(Ink.secondary) }
                }
            }.gridProbe("graph-preview-status",area:"graph-window")
            GraphEditor(graph:model.scene.graph,layout:model.graphLayout,seed:model.scene.seed,state:model.graphEditor,send:model.send,setLayout:model.setGraphLayout,beginEdit:model.beginEdit,endEdit:model.endEdit)
                .disabled(model.files.blocksSceneEditing)
                .gridProbe("graph-editor",area:"graph-window")
        }.gridArea("graph-window",inset:0)
    }
    private var chainWorkspace: some View {
        HStack(alignment: .top, spacing: Space.xl) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .gridProbe("preview-column", area: "page", edge: nil)
            Divider()
            Group {
                if let effect = model.selectedEffect { EffectControls(model: model, effect: effect) }
                else { SourceControls(model: model) }
            }.padding(Space.lg).background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.panel)).frame(width: Layout.controlWidth)
                .disabled(model.files.blocksSceneEditing)
                .gridProbe("parameters-column", area: "page", edge: nil)
        }
    }
    private var preview: some View {
        GeometryReader { geometry in
            let height = min(geometry.size.width * 9 / 16, max(0, geometry.size.height - Layout.previewReservedHeight))
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Live Preview").font(KitType.section).gridProbe("preview-title", area: "preview")
                Group {
                    if let error = model.errorMessage {
                        ContentUnavailableView("Unable to Render", systemImage: KitIcon.warning.rawValue, description: Text(error))
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
                .font(KitType.body).foregroundStyle(Ink.secondary)
                .gridProbe("preview-source", area: "preview")
                EffectChain(model: model)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .gridArea("preview", inset: 0)
    }
}
