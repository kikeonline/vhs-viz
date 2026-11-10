import SwiftUI

public enum Space {
    public static let xs = SignalSpecification.number("space", "xs")
    public static let sm = SignalSpecification.number("space", "sm")
    public static let md = SignalSpecification.number("space", "md")
    public static let lg = SignalSpecification.number("space", "lg")
    public static let xl = SignalSpecification.number("space", "xl")
    public static let xxl = SignalSpecification.number("space", "xxl")
    public static let section = SignalSpecification.number("space", "section")
    /// Window and page margins.
    public static let margin = xl
}
