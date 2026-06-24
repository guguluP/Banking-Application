import SwiftUI

extension Font {
    static func largeTitle() -> Font { .largeTitle.weight(.bold) }
    static func title() -> Font { .title.weight(.bold) }
    static func title2() -> Font { .title2.weight(.semibold) }
    static func headline() -> Font { .headline.weight(.semibold) }
    static func subheadline() -> Font { .subheadline }
    static func body() -> Font { .body }
    static func caption() -> Font { .caption }
    static func caption2() -> Font { .caption2 }
}