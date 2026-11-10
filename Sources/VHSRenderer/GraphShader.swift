import Foundation
import VHSCore

/// Generates only registry-owned Metal; project data never contains executable code.
struct GraphShader {
    let graph: ShaderGraph
    let pass: GraphSchedule.Pass
    func expression(_ endpoint: GraphEndpoint, uv: String = "uv", depth: Int = 0) throws -> String {
        guard depth <= ShaderGraph.maximumNodes, let node = graph.node(endpoint.node) else { throw GraphDiagnostic("Missing expression node.",node:endpoint.node) }
        func input(_ key: String) throws -> String {
            guard let e = graph.input(node.id,key) else { throw GraphDiagnostic("Connect \(key).",node:node.id) }
            return try expression(e,uv:uv,depth:depth+1)
        }
        func stored(_ key: String) throws -> String {
            if let endpoint = graph.input(node.id,key) { return "clamp(\(try expression(endpoint,uv:uv,depth:depth+1)),-1000.0f,1000.0f)" }
            return Self.literal(node.values[key]!)
        }
        let result: String
        switch node.kind {
        case .scalar: result = try stored("value")
        case .vector: result = try "float2(\(stored("x")),\(stored("y")))"
        case .color:
            if let endpoint = graph.input(node.id,"value") { result = try "float4(clamp((\(expression(endpoint,uv:uv,depth:depth+1))).rgb,0.0f,1.0f),1)" }
            else { result = Self.literal(node.values["value"]!) }
        case .uv: result = uv
        case .time: result = "frame.time"
        case .scalarAdd: result = try "gSafe(\(input("a"))+\(input("b")))"
        case .scalarMultiply: result = try "gSafe(\(input("a"))*\(input("b")))"
        case .sine: result = try "sin(\(input("value")))"
        case .vectorAdd: result = try "gSafe2(\(input("a"))+\(input("b")))"
        case .vectorMultiply: result = try "gSafe2(\(input("a"))*\(input("b")))"
        case .composeColor: result = try "float4(clamp(float3(\(input("red")),\(input("green")),\(input("blue"))),0.0f,1.0f),1)"
        case .luminance: result = try "dot((\(input("color"))).rgb,float3(0.2126,0.7152,0.0722))"
        case .colorMix: result = try "mix(\(input("a")),\(input("b")),clamp(\(input("amount")),0.0f,1.0f))"
        case .sampleImage:
            guard let image = graph.input(node.id,"image") else { throw GraphDiagnostic("Connect Image.",node:node.id) }
            result = try sample(image.node,uv:input("uv"))
        default: result = try sample(node.id,uv:uv)
        }
        guard result.utf8.count <= 65_536 else { throw GraphDiagnostic("Expression exceeds 64 KiB. Simplify shared math branches.",node:node.id) }
        return result
    }
    private func sample(_ id: UUID, uv: String) throws -> String {
        guard let producer = pass.imageInputs[id], let index = pass.inputs.firstIndex(of:producer) else { throw GraphDiagnostic("Missing image dependency.",node:pass.node.id) }
        return "image\(index).sample(graphSampler,\(uv))"
    }
    private func value(_ key: String) throws -> String {
        if let e = graph.input(pass.node.id,key) { return try expression(e) }
        guard let value = pass.node.values[key] else { throw GraphDiagnostic("Missing \(key).",node:pass.node.id) }
        return Self.literal(value)
    }
    static func literal(_ value: ParameterValue) -> String {
        switch value {
        case let .number(v): "\(Float(v))f"
        case let .color(c): "float4(\(Float(c.red))f,\(Float(c.green))f,\(Float(c.blue))f,1)"
        default: "0.0f"
        }
    }
    private func vector(_ v: SIMD4<Float>) -> String { "float4(\(v.x)f,\(v.y)f,\(v.z)f,\(v.w)f)" }
    func fragment() throws -> String {
        let textures = pass.inputs.indices.map { ", texture2d<float> image\($0) [[texture(\($0))]]" }.joined()
        let body: String
        let node = pass.node
        switch node.kind {
        case let .source(kind):
            let values = Dictionary(uniqueKeysWithValues:node.values.compactMap { key,v in ParameterID(rawValue:key).map { ($0,v) } })
            let scene = SceneSnapshot(source:kind,values:values)
            let u = SourceUniforms(.init(scene:scene,time:0),width:1,height:1)
            var code = "SourceUniforms u={}; u.resolution=frame.resolution; u.seed=frame.seed; u.kind=\(u.kind); u.variant=\(u.variant); u.colorA=\(vector(u.colorA)); u.colorB=\(vector(u.colorB)); u.p0=\(vector(u.p0)); u.p1=\(vector(u.p1));"
            let assignments: [ParameterID:String] = [
                .solidRed:"colorA.r",.solidGreen:"colorA.g",.solidBlue:"colorA.b",
                .gradientStart:"colorA",.gradientEnd:"colorB",.gradientAngle:"p0.x",.gradientX:"p0.y",.gradientY:"p0.z",
                .noiseScale:"p0.x",.noiseContrast:"p0.y",.noiseLow:"colorA",.noiseHigh:"colorB",
                .oscillatorFrequency:"p0.x",.oscillatorAngle:"p0.z",.oscillatorPhase:"p0.w",.oscillatorForeground:"colorA",.oscillatorBackground:"colorB",
                .shapeSize:"p0.x",.shapeX:"p0.y",.shapeY:"p0.z",.shapeRotation:"p0.w",.shapeSoftness:"p1.x",.shapeWidth:"p1.y",.shapeFill:"colorA",.shapeBackground:"colorB"
            ]
            for p in kind.definition.parameters where graph.input(node.id,p.id.rawValue) != nil {
                guard let field = assignments[p.id] else { continue }
                var v = try value(p.id.rawValue)
                if case let .number(range) = p.kind { v = "clamp(\(v),\(Float(range.lowerBound))f,\(Float(range.upperBound))f)" }
                if [.gradientAngle,.oscillatorAngle,.shapeRotation].contains(p.id) { v = "(\(v))*M_PI_F/180.0f" }
                code += "u.\(field)=\(v);"
            }
            if kind == .noise && scene.enabled(.noiseAnimate) { code += try "u.time=fmod(frame.time*clamp(\(value(ParameterID.noiseSpeed.rawValue)),0.0f,2.0f),4096.0f);" }
            if kind == .oscillator && scene.enabled(.oscillatorAnimate) { code += try "u.time=fmod(frame.time*clamp(\(value(ParameterID.oscillatorSpeed.rawValue)),-2.0f,2.0f),4096.0f);" }
            body = code+"return sourceImage(in.position.xy,u);"
        case let .effect(kind):
            let imageIndex: Int
            if pass.verticalBlur { imageIndex = pass.inputs.count-1 }
            else {
                guard let image = graph.input(node.id,"image"), let producer = pass.imageInputs[image.node], let index = pass.inputs.firstIndex(of:producer) else { throw GraphDiagnostic("Connect Image.",node:node.id) }
                imageIndex = index
            }
            if node.bypassed { body = "return image\(imageIndex).sample(graphSampler,uv);"; break }
            var effect = EffectInstance(id:node.id,kind:kind)
            // Registry values have already been validated; the uniforms provide static defaults.
            for (key,v) in node.values {
                let holder = SceneSnapshot(source:.solid,effects:[effect])
                effect = SceneReducer.reduce(holder,.setEffectValue(effect.id,key,v)).effects[0]
            }
            let u = EffectUniforms(effect,width:1,height:1,verticalBlur:pass.verticalBlur)
            var code = "EffectUniforms u={}; u.resolution=frame.resolution; u.kind=\(u.kind); u.p0=\(vector(u.p0)); u.colorA=\(vector(u.colorA)); u.colorB=\(vector(u.colorB));"
            let fields: [EffectKind:[String:String]] = [
                .transform:["x":"p0.x","y":"p0.y","rotation":"p0.z","scale":"p0.w"],.blur:["radius":"p0.x"],.pixelate:["size":"p0.x"],
                .threshold:["level":"p0.x","softness":"p0.y"],.colorize:["amount":"p0.x","low":"colorA","high":"colorB"],.rgbSplit:["x":"p0.x","y":"p0.y"]
            ]
            for p in kind.definition.parameters where graph.input(node.id,p.id) != nil {
                var v = try value(p.id)
                if case let .number(r) = p.kind { v = "clamp(\(v),\(Float(r.lowerBound))f,\(Float(r.upperBound))f)" }
                if kind == .transform && p.id == "rotation" { v = "(\(v))*M_PI_F/180.0f" }
                code += "u.\(fields[kind]![p.id]!)=\(v);"
            }
            body = code+"return effectImage(in.position.xy,u,image\(imageIndex));"
        case .imageFromColor:
            guard let e = graph.input(node.id,"color") else { throw GraphDiagnostic("Connect Color.",node:node.id) }
            body = try "return float4((\(expression(e))).rgb,1);"
        case .imageMix:
            guard let a = graph.input(node.id,"a"), let b = graph.input(node.id,"b"), let amount = graph.input(node.id,"amount") else { throw GraphDiagnostic("Connect both images and Amount.",node:node.id) }
            body = try "return float4(mix((\(sample(a.node,uv:"uv"))).rgb,(\(sample(b.node,uv:"uv"))).rgb,clamp(\(expression(amount)),0.0f,1.0f)),1);"
        case .output:
            guard let image = graph.input(node.id,"image") else { throw GraphDiagnostic("Connect Output’s Image.",node:node.id) }
            body = try "return float4((\(sample(image.node,uv:"uv"))).rgb,1);"
        default: throw GraphDiagnostic("This value node does not produce an image pass.",node:node.id)
        }
        return """
        struct GraphFrame { float2 resolution; float time; uint seed; };
        float gSafe(float v) { return isfinite(v) ? clamp(v,-1000000.0f,1000000.0f) : 0.0f; }
        float2 gSafe2(float2 v) { return float2(gSafe(v.x),gSafe(v.y)); }
        fragment float4 graphFragment(VertexOut in [[stage_in]], constant GraphFrame &frame [[buffer(0)]]\(textures)) {
            constexpr sampler graphSampler(coord::normalized,address::clamp_to_edge,filter::linear);
            float2 uv=in.position.xy/frame.resolution;
            \(body)
        }
        """
    }
}
