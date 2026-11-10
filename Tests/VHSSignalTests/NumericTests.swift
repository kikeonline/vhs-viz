import Foundation
import Testing
import VHSSignal
import VHSCore

@MainActor @Test(arguments: ["", " ", "nan", "inf", "1abc", "0.5.2", "--1", "1e999", "-0.1", "1.1"])
func invalidDraftDoesNotCommit(_ text: String) {
    var draft = NumericDraft(text)
    let value = draft.commit(in: 0...1, locale: Locale(identifier: "en_US"))
    #expect(value == nil)
    #expect(draft.isInvalid && draft.text == text)
    draft.cancel("0.24")
    #expect(!draft.isInvalid && draft.text == "0.24")
}
@MainActor @Test func exactEditsAndGestureHistory() throws {
    var session = ProjectSession(document: .init())
    let initial = session.history.scene
    var draft = NumericDraft("0.375")
    #expect(!session.isDirty && !session.history.canUndo)
    let committed = draft.commit(in: 0...1)
    session.send(.setValue(.solidRed, .number(try #require(committed))))
    #expect(session.isDirty && session.history.past.count == 1)
    session.undo(); #expect(session.history.scene == initial && !session.isDirty)
    session.redo(); #expect(session.history.scene.number(.solidRed) == 0.375)
    // Escape discards the draft. No action is sent and no history is added.
    draft.replace("0.9"); draft.cancel("0.375")
    let unchanged = draft.commit(in: 0...1)
    session.send(.setValue(.solidRed, .number(try #require(unchanged))))
    #expect(session.history.past.count == 1)
    session.beginEdit()
    for value in [0.4, 0.5, 0.6] { session.send(.setValue(.solidRed, .number(value))) }
    session.endEdit()
    #expect(session.history.past.count == 2)
    session.undo(); #expect(session.history.scene.number(.solidRed) == 0.375)
    let definition = SourceRegistry.parameter(.solidRed)
    session.send(.setValue(.solidRed, definition.defaultValue))
    #expect(session.history.scene == initial && !session.isDirty)
    session.undo(); #expect(session.history.scene.number(.solidRed) == 0.375)
}
@MainActor @Test func integerBoundariesAndLocale() {
    #expect(NumericDraft("4294967295").value(in: 0...Double(UInt32.max), integer: true) == Double(UInt32.max))
    #expect(NumericDraft("1.5").value(in: 0...10, integer: true) == nil)
    #expect(NumericDraft("0,125").value(in: 0...1, locale: Locale(identifier: "fr_FR")) == 0.125)
    #expect(NumericDraft("-180").value(in: -180...180) == -180)
    #expect(NumericDraft("180").value(in: -180...180) == 180)
}

@MainActor @Test func nativeKitLoadsBundledSpecification() {
    // Exercise runtime consumers too: type metadata includes nonnumeric presentation notes.
    #expect(Layout.defaultWidth > Layout.minWidth && Space.margin > Space.sm)
    _ = [KitType.title, KitType.section, KitType.body, KitType.label, KitType.meta, KitType.value]
    _ = [Ink.canvas, Ink.surface, Ink.raised, Ink.hover, Ink.text, Ink.secondary, Ink.muted, Ink.divider, Ink.border, Ink.selection, Ink.error, Ink.accent]
}
