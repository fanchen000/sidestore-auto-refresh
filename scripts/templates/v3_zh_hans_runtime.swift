// V3_ZH_HANS_RUNTIME_V1_BEGIN
// Simplified Chinese presentation layer for the unified LC+SS shell.
// Literal UI text and runtime status/error strings both reach SwiftUI as
// plain Strings through the module-local Text/Label/Button/Toggle/Section/
// navigationTitle overloads below, so they are translated at the display
// boundary only. Backend values, comparisons and wire contracts keep their
// original English strings.

enum V3ZH {
    static let isChinese: Bool = {
        if let first = Bundle.main.preferredLocalizations.first, first.hasPrefix("zh") { return true }
        return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }()

    private struct Table: Decodable {
        let exact: [String: String]
        let patterns: [[String]]
    }

    private struct Pattern {
        let regex: NSRegularExpression
        let template: String
        let weight: Int
    }

    private static let exact: [String: String] = loaded.exact
    private static let patterns: [Pattern] = loaded.patterns

    private static let loaded: (exact: [String: String], patterns: [Pattern]) = {
        guard let data = V3ZHData.json.data(using: .utf8),
              let table = try? JSONDecoder().decode(Table.self, from: data) else { return ([:], []) }
        var compiled: [Pattern] = []
        for pair in table.patterns where pair.count == 2 {
            let parts = pair[0].components(separatedBy: "{}")
            let body = parts.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "(.*?)")
            if let regex = try? NSRegularExpression(pattern: "^" + body + "$", options: [.dotMatchesLineSeparators]) {
                compiled.append(Pattern(regex: regex, template: pair[1], weight: parts.joined().count))
            }
        }
        compiled.sort { $0.weight > $1.weight }
        return (table.exact, compiled)
    }()

    private static let lock = NSLock()
    private static var cache: [String: String] = [:]
    private static let sentenceBreak = try? NSRegularExpression(pattern: "(?<=[.!?:])\\s+", options: [])

    static func t(_ raw: String) -> String {
        guard isChinese, !raw.isEmpty else { return raw }
        lock.lock()
        if let hit = cache[raw] { lock.unlock(); return hit }
        lock.unlock()
        let result = translate(raw, depth: 0)
        lock.lock()
        if cache.count > 4096 { cache.removeAll(keepingCapacity: true) }
        cache[raw] = result
        lock.unlock()
        return result
    }

    private static func isCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x3000...0x9FFF).contains($0.value) || (0xFF00...0xFFEF).contains($0.value) }
    }

    private static func translate(_ raw: String, depth: Int) -> String {
        if let hit = exact[raw] { return hit }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isCJK(trimmed) && !trimmed.contains(where: { $0.isASCII && $0.isLetter }) { return raw }
        if trimmed != raw, let hit = exact[trimmed] { return hit }
        if depth > 4 { return raw }

        if trimmed.contains("\n") {
            let lines = trimmed.components(separatedBy: "\n")
            let mapped = lines.map { translate($0, depth: depth + 1) }
            if mapped != lines { return mapped.joined(separator: "\n") }
        }

        let ns = trimmed as NSString
        let full = NSRange(location: 0, length: ns.length)
        for pattern in patterns {
            guard let match = pattern.regex.firstMatch(in: trimmed, options: [], range: full),
                  match.range.length == ns.length else { continue }
            var output = pattern.template
            for index in 1..<match.numberOfRanges {
                let range = match.range(at: index)
                let capture = range.location == NSNotFound ? "" : ns.substring(with: range)
                let piece = translate(capture, depth: depth + 1)
                if let slot = output.range(of: "{}") { output.replaceSubrange(slot, with: piece) }
            }
            return output
        }

        if let sentenceBreak {
            var pieces: [String] = []
            var start = 0
            for match in sentenceBreak.matches(in: trimmed, options: [], range: full) {
                pieces.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
                start = match.range.location + match.range.length
            }
            pieces.append(ns.substring(from: start))
            if pieces.count > 1 {
                let mapped = pieces.map { translate($0, depth: depth + 1) }
                if mapped != pieces {
                    var output = ""
                    for (index, piece) in mapped.enumerated() {
                        if index > 0, !(isCJK(piece) && isCJK(mapped[index - 1])) { output += " " }
                        output += piece
                    }
                    return output
                }
            }
        }
        return raw
    }

    static func resolve(_ raw: String) -> String {
        let translated = t(raw)
        if translated != raw { return translated }
        return Bundle.main.localizedString(forKey: raw, value: raw, table: nil)
    }

    static func looksLikeMarkdown(_ raw: String) -> Bool {
        raw.contains("**") || raw.contains("](") || raw.contains("`")
    }
}

extension Text {
    init(_ content: String) {
        let translated = V3ZH.t(content)
        if translated != content {
            self.init(verbatim: translated)
        } else if V3ZH.looksLikeMarkdown(content) {
            self.init(LocalizedStringKey(content))
        } else {
            self.init(verbatim: Bundle.main.localizedString(forKey: content, value: content, table: nil))
        }
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: String, systemImage name: String) {
        self.init(title: { Text(title) }, icon: { Image(systemName: name) })
    }
}

extension Button where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action, label: { Text(title) })
    }

    @available(iOS 15.0, *)
    init(_ title: String, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action, label: { Text(title) })
    }
}

extension Toggle where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn, label: { Text(title) })
    }
}

@available(iOS 15.0, *)
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(title) })
    }
}

extension View {
    func navigationTitle(_ title: String) -> some View {
        navigationTitle(Text(title))
    }
}

enum V3ZHData {
    static let json = #"""
__V3ZH_JSON__
"""#
}
// V3_ZH_HANS_RUNTIME_V1_END
