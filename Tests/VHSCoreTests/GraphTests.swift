import Foundation
import Testing
@testable import VHSCore

private func link(_ from: GraphNode, _ to: GraphNode, _ port: String) -> GraphEdge { .init(from:.init(from.id),to:.init(to.id,port)) }
private func branch() -> ShaderGraph {
    let a = GraphNode(kind:.source(.gradient)), b = GraphNode(kind:.source(.noise)), amount = GraphNode(kind:.scalar)
    let mix = GraphNode(kind:.imageMix), output = GraphNode(kind:.output)
    return .init(nodes:[a,b,amount,mix,output],edges:[link(a,mix,"a"),link(b,mix,"b"),link(amount,mix,"amount"),link(mix,output,"image")])
}
@Test func graphValidationTypesCyclesAndRequiredInputs() throws {
    let graph = branch(); try GraphValidator.validate(graph)
    #expect(graph.chain == nil)
    let mix = graph.nodes[3], source = graph.nodes[0], amount = graph.nodes[2]
    #expect(throws:GraphDiagnostic.self) { try graph.connecting(.init(amount.id),to:.init(mix.id,"a")) }
    #expect(throws:GraphDiagnostic.self) { try graph.connecting(.init(mix.id),to:.init(mix.id,"a")) }
    #expect(throws:GraphDiagnostic.self) { try graph.connecting(.init(UUID()),to:.init(mix.id,"a")) }
    let incomplete = try graph.connecting(nil,to:.init(mix.id,"a"))
    try GraphValidator.validate(incomplete,requireComplete:false)
    do { try GraphValidator.validate(incomplete); Issue.record("Missing input accepted") }
    catch let error as GraphDiagnostic { #expect(error.node == mix.id && error.message.contains("A")) }
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(.init(nodes:graph.nodes+[graph.nodes[0]],edges:graph.edges)) }
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(.init(nodes:graph.nodes+[.init(kind:.output)],edges:graph.edges)) }
    #expect(throws:GraphDiagnostic.self) { try graph.connecting(.init(source.id,"unknown"),to:.init(mix.id,"a")) }
    let bad = GraphNode(id:amount.id,kind:.scalar,values:["value":.number(.nan)])
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(graph.replacing(bad)) }
}
@Test func graphLimitsAreEnforcedBeforeCompilation() throws {
    let graph = branch()
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(.init(nodes:graph.nodes+(0..<64).map { _ in .init(kind:.scalar) },edges:graph.edges)) }
    var chain = SceneSnapshot()
    // Pass limit is independent from the simple-chain 16-effect limit.
    var nodes = [graph.nodes[0]], edges: [GraphEdge] = []; var previous = nodes[0]
    for _ in 0..<32 { let node = GraphNode(kind:.effect(.blur)); nodes.append(node); edges.append(link(previous,node,"image")); previous = node }
    let output = GraphNode(kind:.output); nodes.append(output); edges.append(link(previous,output,"image"))
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(.init(nodes:nodes,edges:edges)) }
    let sources = (0..<9).map { _ in GraphNode(kind:.source(.solid)) }, amount = GraphNode(kind:.scalar)
    nodes = sources+[amount]; edges = []; previous = sources[0]
    for source in sources.dropFirst() {
        let mix = GraphNode(kind:.imageMix); nodes.append(mix)
        edges += [link(previous,mix,"a"),link(source,mix,"b"),link(amount,mix,"amount")]; previous = mix
    }
    nodes.append(output); edges.append(link(previous,output,"image"))
    #expect(throws:GraphDiagnostic.self) { try GraphValidator.validate(.init(nodes:nodes,edges:edges)) }
    chain = SceneReducer.reduce(chain,.addEffect(.init(kind:.blur)))
    let migrated = chain.graph
    #expect(migrated.chain?.effects == chain.effects)
    #expect(try GraphSchedule(graph:migrated,ordered:GraphValidator.validate(migrated)).textureCount <= 2)
}
@Test func graphHistoryLayoutTargetsAndRoundTrip() throws {
    let graph = branch()
    var session = ProjectSession(document:.init(scene:SceneSnapshot().withGraph(graph)))
    let node = graph.nodes[2], target = GraphParameterTarget(node:node.id,key:"value")
    #expect(target.definition(in:graph)?.title == "Value")
    session.beginEdit(); session.send(.setNodeValue(node.id,"value",.number(0.2))); session.send(.setNodeValue(node.id,"value",.number(0.8))); session.endEdit()
    #expect(session.history.past.count == 1)
    session.undo(); #expect(session.history.scene.graph == graph); session.redo()
    let layout = GraphLayout(positions:[node.id.uuidString:.init(x:144,y:288)],pan:.init(x:-64,y:128),zoom:0.75)
    session.setGraphLayout(layout)
    #expect(session.history.past.count == 1 && session.isDirty)
    #expect(try ProjectCodec.decode(ProjectCodec.encode(session.document)) == session.document)
    let duplicate = graph.duplicated(node.id)
    #expect(duplicate.nodes.last?.id != node.id)
    let removed = graph.removing(node.id)
    #expect(target.definition(in:removed) == nil && target.unavailableMessage.contains(node.id.uuidString))
    let replacement = removed.adding(.init(kind:.scalar))
    #expect(target.definition(in:replacement) == nil)
    #expect(graph.removing(graph.nodes.last!.id) == graph)
    #expect(SceneReducer.reduce(session.history.scene,.selectSource(.solid)) == session.history.scene)
    let count = session.history.past.count
    session.setGraphLayout(.init(zoom:.infinity)); #expect(session.graphLayout == layout && session.history.past.count == count)
    var json = try #require(JSONSerialization.jsonObject(with:ProjectCodec.encode(session.document)) as? [String:Any])
    var scene = json["scene"] as! [String:Any]; var rawGraph = scene["graph"] as! [String:Any]
    var rawNodes = rawGraph["nodes"] as! [[String:Any]]; rawNodes[0]["kind"] = ["alien":[:]]
    rawGraph["nodes"] = rawNodes; scene["graph"] = rawGraph; json["scene"] = scene
    #expect(throws:(any Error).self) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject:json)) }
}
@Test func schemaThreeMigrationCreatesStableEquivalentGraph() throws {
    let effect = EffectInstance(kind:.pixelate)
    let original = ProjectDocument(scene:.init(source:.shape,seed:111,effects:[effect]))
    var json = try #require(JSONSerialization.jsonObject(with:ProjectCodec.encode(original)) as? [String:Any])
    var scene = json["scene"] as! [String:Any]; scene.removeValue(forKey:"graph"); json["scene"] = scene
    json["schemaVersion"] = 3; json.removeValue(forKey:"graphLayout")
    let data = try JSONSerialization.data(withJSONObject:json)
    let a = try ProjectCodec.decode(data), b = try ProjectCodec.decode(data)
    #expect(a == original && b == a)
    #expect(a.scene.graph.nodes[1].id == effect.id)
    #expect(a.scene.graph.chain?.effects == [effect])
}

@Test func customChainNodeIdentitiesSurviveBothEditors() throws {
    let source = GraphNode(kind:.source(.solid)), fx = GraphNode(kind:.effect(.pixelate)), output = GraphNode(kind:.output)
    let graph = ShaderGraph(nodes:[source,fx,output],edges:[link(source,fx,"image"),link(fx,output,"image")])
    var scene = SceneSnapshot().withGraph(graph)
    scene = SceneReducer.reduce(scene,.setParameter(.solidRed,0.8))
    scene = SceneReducer.reduce(scene,.setEffectValue(fx.id,"size",.number(20)))
    #expect(scene.graph.nodes.map(\.id) == [source.id,fx.id,output.id])
    scene = SceneReducer.reduce(scene,.selectSource(.gradient))
    #expect(scene.graph.nodes[0].id == source.id && scene.graph.nodes.last?.id == output.id)
    try scene.validate()
}
