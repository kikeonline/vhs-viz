import SwiftUI

public enum Layout {
    public static let inputWidth: CGFloat = 400
    public static let inputMaxHeight: CGFloat = 560
    public static let graphSeedWidth: CGFloat = 72
    public static let graphMinWidth = SignalSpecification.number("metric", "graphMinWidth")
    public static let graphMinHeight = SignalSpecification.number("metric", "graphMinHeight")
    public static let graphPreviewWidth: CGFloat = 240
    public static let graphNodeWidth = SignalSpecification.number("metric", "nodeWidth")
    public static let graphNodeHeader = SignalSpecification.number("metric", "nodeHeader")
    public static let graphPortHeight = SignalSpecification.number("metric", "portRow")
    public static let graphNodeFooter: CGFloat = 32
    public static let graphLibraryWidth: CGFloat = 320
    public static let graphLibraryHeight: CGFloat = 360
    public static let graphInspectorWidth = SignalSpecification.number("metric", "inspectorWidth")
    public static let graphPanStep: Double = 128

    /// Title, source status, section gaps and the minimum effect section.
    public static let previewReservedHeight: CGFloat = 192
    public static let effectListMinHeight: CGFloat = 80
    public static let sheetWidth: CGFloat = 480
    public static let controlWidth = SignalSpecification.number("metric", "inspectorWidth")
    public static let previewWidth: CGFloat = 560
    public static let previewHeight: CGFloat = 316
    public static let minWidth = SignalSpecification.number("metric", "windowMinWidth")
    public static let minHeight = SignalSpecification.number("metric", "windowMinHeight")
    public static let defaultWidth = SignalSpecification.number("metric", "windowDefaultWidth")
    public static let defaultHeight = SignalSpecification.number("metric", "windowDefaultHeight")
    public static let previewRadius = SignalSpecification.number("radius", "preview")
}
