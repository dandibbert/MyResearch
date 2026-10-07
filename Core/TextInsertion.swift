import Foundation

enum TextInsertion {
    static func inserting(_ token: String, into text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let source = text as NSString
        var range = selection
        if range.location == NSNotFound || range.location > source.length || range.location + range.length > source.length {
            range = NSRange(location: source.length, length: 0)
        }
        let updated = source.replacingCharacters(in: range, with: token)
        let cursor = range.location + (token as NSString).length
        return (updated, NSRange(location: cursor, length: 0))
    }
}
