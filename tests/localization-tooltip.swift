import Foundation
import SwiftUI

@_silgen_name("DPTooltipTextEntry")
func intercepted<S: StringProtocol>(_ value: consuming S) -> Text
@_silgen_name("DPTooltipTestStart") func start()
@_silgen_name("DPTooltipTestEnd") func end()
@_silgen_name("DPTooltipTestSetScope") func scope(_ enabled: Int32)

func strings(_ value: Any, depth: Int = 0) -> [String] {
    if let string = value as? String { return [string] }
    if depth > 10 { return [] }
    return Mirror(reflecting:value).children.flatMap { strings($0.value, depth:depth+1) }
}
@main struct Test {
    static func main() {
        start(); defer { end() }
        let cases = [("Toggle sidebar","切换侧边栏"), ("Click to go back","点按后退"),
                     ("Click to go forward","点按前进"), ("Split tabs","分屏标签页"),
                     ("Site menu","网站菜单"), ("Bookmark this page","将此页面加入书签"),
                     ("Included in AI history search","已纳入 AI 历史记录搜索"), ("New tab","新建标签页")]
        for _ in 0..<2000 {
            for (source, translation) in cases {
                // Exercise heap Strings, retain the caller's copy, and alternate
                // original/transformed calls exactly as reused tooltips do.
                let input = String(source.utf8.map { Character(UnicodeScalar($0)) })
                let rendered = strings(intercepted(input))
                if !rendered.contains(translation) { FileHandle.standardError.write(Data("Mismatch: \(source): \(rendered) expected \(translation)\n".utf8)) }
                precondition(rendered.contains(translation))
                precondition(input == source)
                precondition(strings(Text(input)).contains(source))
                scope(0)
                precondition(strings(intercepted(input)).contains(source))
                scope(1)
            }
        }
        let substring = "Toggle sidebar"[...]
        precondition(strings(intercepted(substring)).contains("Toggle sidebar"))
        precondition(strings(intercepted("Uncatalogued text")).contains("Uncatalogued text"))
        print("Tooltip ABI: 16000 repeated translations; original caller storage, scope exclusion, Substring and unknown fallback passed")
    }
}
