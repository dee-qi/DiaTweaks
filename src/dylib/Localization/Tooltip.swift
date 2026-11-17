import Foundation

@_silgen_name("DPTooltipLookup")
private func lookup(_ source: UnsafeRawPointer) -> UnsafeMutableRawPointer?

// Text.init<S: StringProtocol> consumes an indirectly passed S. Only rewrite
// that owned argument when its metadata is exactly Swift.String. Assignment
// releases the original argument and leaves one owned translated String for
// SwiftUI to consume; the caller's original value remains untouched.
@_cdecl("DPRewriteTooltipString")
func rewriteTooltipString(_ argument: UnsafeMutableRawPointer, _ metadata: UnsafeRawPointer) {
    guard metadata == unsafeBitCast(String.self, to: UnsafeRawPointer.self) else { return }
    let string = argument.assumingMemoryBound(to: String.self)
    let source = string.pointee as NSString
    guard let result = lookup(Unmanaged.passUnretained(source).toOpaque()) else { return }
    string.pointee = Unmanaged<NSString>.fromOpaque(result).takeRetainedValue() as String
}
