import SwiftUI
import VHSCore

struct RenameProjectView: View {
    let model: AppModel
    @State private var name: String
    @FocusState private var nameFocused: Bool
    init(model: AppModel) { self.model = model; _name = State(initialValue: model.projectName) }
    private var validation: String? {
        do { _ = try ProjectDocument.validatedName(name); return nil }
        catch { return error.localizedDescription }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Text("Rename Project").font(.headline).gridProbe("rename-heading", area: "rename")
            VStack(alignment: .leading, spacing: Space.sm) {
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .accessibilityLabel("Project name")
                    .disabled(model.files.isBusy)
                    .onSubmit { submit() }
                if let error = model.files.renameError ?? validation {
                    Text(error).font(.callout).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.gridProbe("rename-field", area: "rename")
            HStack {
                Spacer()
                Button("Cancel") { model.files.isRenaming = false }.keyboardShortcut(.cancelAction)
                    .disabled(model.files.isBusy)
                Button("Rename") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(validation != nil || model.files.isBusy)
            }.gridProbe("rename-buttons", area: "rename", edge: nil)
        }
        .padding(Space.margin)
        .frame(width: Layout.sheetWidth)
        .gridArea("rename")
        .interactiveDismissDisabled(model.files.isBusy)
        .onAppear { nameFocused = true }
        .onChange(of: name) { _, _ in model.files.renameError = nil }
        .onChange(of: model.files.isBusy) { _, busy in
            if !busy { nameFocused = true }
        }
    }
    private func submit() {
        guard validation == nil else { return }
        Task { _ = await model.files.renameProject(to: name) }
    }
}
