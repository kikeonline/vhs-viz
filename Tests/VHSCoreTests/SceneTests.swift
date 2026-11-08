import Testing
@testable import VHSCore

@Test func reducerPreservesOriginalAndSeed() {
    let original = SceneSnapshot(seed: 42)
    let next = SceneReducer.reduce(original, .setParameter(.solidRed, 0.75))
    #expect(original.color == .initial)
    #expect(next.color.red == 0.75)
    #expect(next.color.green == original.color.green)
    #expect(next.seed == 42)
}

@Test(arguments: [(-1.0, 0.0), (2.0, 1.0), (Double.infinity, 0.0), (Double.nan, 0.0), (0.5, 0.5)])
func parameterValidation(input: Double, expected: Double) {
    let scene = SceneReducer.reduce(.init(), .setParameter(.solidGreen, input))
    #expect(scene.color.green == expected)
}

@Test func gestureIsOneUndoAndRedo() {
    var history = SceneHistory()
    let initial = history.scene
    history.beginEdit()
    for n in 0...100 { history.send(.setParameter(.solidBlue, Double(n) / 100)) }
    history.endEdit()
    #expect(history.past.count == 1)
    let final = history.scene
    history.undo(); #expect(history.scene == initial)
    history.redo(); #expect(history.scene == final)
}

@Test func branchingInvalidatesRedoAndNoOpDoesNot() {
    var history = SceneHistory()
    history.send(.setParameter(.solidRed, 1)); history.undo()
    history.send(.setColor(history.scene.color))
    #expect(history.canRedo)
    history.send(.setParameter(.solidGreen, 1))
    #expect(!history.canRedo)
}

@Test func noOpGestureAndUndoDuringDrag() {
    var history = SceneHistory()
    history.beginEdit(); history.endEdit()
    #expect(!history.canUndo)
    let start = history.scene
    history.beginEdit(); history.send(.setParameter(.solidRed, 1)); history.undo()
    #expect(history.scene == start)
    history.redo(); #expect(history.scene.color.red == 1)
}

@Test func historyIsBounded() {
    var history = SceneHistory()
    for n in 0..<500 { history.send(.setParameter(.solidRed, Double(n % 2))) }
    #expect(history.past.count == 200)
}

@Test func fixedClockIsRepeatable() {
    let clock = RenderClock(fixedTime: 12.5)
    #expect(clock.time == 12.5)
    #expect(RenderFrame(scene: .init(seed: 9), time: clock.time) == RenderFrame(scene: .init(seed: 9), time: 12.5))
}
