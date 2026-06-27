import Foundation

nonisolated indirect enum YAMLValue {
    case scalar(String)
    case mapping([(String, YAMLValue)])
    case sequence([YAMLValue])

    var scalarValue: String? {
        if case let .scalar(value) = self { return value }
        return nil
    }
}

nonisolated struct ComposeService: Equatable, Identifiable {
    let name: String
    var image: String?
    var containerName: String?
    var command: [String]
    var ports: [String]
    var environment: [String]
    var volumes: [String]
    var dependsOn: [String]
    var labels: [String: String]

    var id: String { name }

    var displayName: String { containerName ?? name }
}

nonisolated struct ComposeProject: Equatable {
    let name: String
    let services: [ComposeService]
    let namedVolumes: [String]

    static func parse(_ source: String, defaultName: String) -> ComposeProject? {
        var parser = ComposeParser(source)
        guard case let .mapping(root) = parser.parse() else { return nil }

        let name = root.scalar("name") ?? defaultName
        guard case let .mapping(servicesMap)? = root.value("services") else { return nil }

        var services: [ComposeService] = []
        for (serviceName, value) in servicesMap {
            guard case let .mapping(fields) = value else { continue }
            services.append(ComposeService(name: serviceName, fields: fields))
        }
        guard !services.isEmpty else { return nil }

        var named: [String] = []
        if case let .mapping(volumesMap)? = root.value("volumes") {
            named = volumesMap.map(\.0)
        }

        return ComposeProject(name: name, services: services, namedVolumes: named)
    }

    /// Services in dependency order (depends_on before dependents); falls back to declared order on a cycle.
    func runOrder() -> [ComposeService] {
        let byName = Dictionary(uniqueKeysWithValues: services.map { ($0.name, $0) })
        var remaining = services
        var ordered: [ComposeService] = []
        var placed = Set<String>()

        while !remaining.isEmpty {
            let ready = remaining.filter { service in
                service.dependsOn.allSatisfy { !byName.keys.contains($0) || placed.contains($0) }
            }
            if ready.isEmpty {
                ordered.append(contentsOf: remaining)
                break
            }
            for service in ready {
                ordered.append(service)
                placed.insert(service.name)
            }
            remaining.removeAll { placed.contains($0.name) }
        }
        return ordered
    }
}

extension ComposeService {
    nonisolated init(name: String, fields: [(String, YAMLValue)]) {
        self.name = name
        self.image = fields.scalar("image")
        self.containerName = fields.scalar("container_name")
        self.command = ComposeService.commandTokens(fields.value("command"))
        self.ports = ComposeService.portSpecs(fields.value("ports"))
        self.environment = ComposeService.environmentPairs(fields.value("environment"))
        self.volumes = ComposeService.scalarList(fields.value("volumes"))
        self.dependsOn = ComposeService.dependencyNames(fields.value("depends_on"))
        self.labels = ComposeService.labelMap(fields.value("labels"))
    }

    nonisolated private static func commandTokens(_ value: YAMLValue?) -> [String] {
        switch value {
        case let .scalar(text): return ComposeParser.tokenize(text)
        case let .sequence(items): return items.compactMap(\.scalarValue)
        default: return []
        }
    }

    nonisolated private static func portSpecs(_ value: YAMLValue?) -> [String] {
        guard case let .sequence(items) = value else { return [] }
        return items.compactMap { item in
            switch item {
            case let .scalar(text):
                return text
            case let .mapping(pairs):
                let published = pairs.scalar("published") ?? pairs.scalar("target")
                guard let target = pairs.scalar("target") else { return nil }
                return published.map { "\($0):\(target)" } ?? target
            default:
                return nil
            }
        }
    }

    nonisolated private static func environmentPairs(_ value: YAMLValue?) -> [String] {
        switch value {
        case let .sequence(items):
            return items.compactMap(\.scalarValue)
        case let .mapping(pairs):
            return pairs.map { "\($0.0)=\($0.1.scalarValue ?? "")" }
        default:
            return []
        }
    }

    nonisolated private static func scalarList(_ value: YAMLValue?) -> [String] {
        guard case let .sequence(items) = value else { return [] }
        return items.compactMap(\.scalarValue)
    }

    nonisolated private static func dependencyNames(_ value: YAMLValue?) -> [String] {
        switch value {
        case let .sequence(items): return items.compactMap(\.scalarValue)
        case let .mapping(pairs): return pairs.map(\.0)
        default: return []
        }
    }

    nonisolated private static func labelMap(_ value: YAMLValue?) -> [String: String] {
        switch value {
        case let .mapping(pairs):
            return Dictionary(pairs.map { ($0.0, $0.1.scalarValue ?? "") }, uniquingKeysWith: { _, last in last })
        case let .sequence(items):
            var result: [String: String] = [:]
            for case let .scalar(text) in items {
                if let eq = text.firstIndex(of: "=") {
                    result[String(text[..<eq])] = String(text[text.index(after: eq)...])
                } else {
                    result[text] = ""
                }
            }
            return result
        default:
            return [:]
        }
    }
}

private extension Array where Element == (String, YAMLValue) {
    nonisolated func value(_ key: String) -> YAMLValue? {
        first(where: { $0.0 == key })?.1
    }

    nonisolated func scalar(_ key: String) -> String? {
        value(key)?.scalarValue
    }
}

/// A purpose-built parser for the block-style YAML subset that Docker Compose files use.
/// Flow style (`[a, b]`), multi-line block scalars (`|`, `>`), and anchors are out of scope.
nonisolated struct ComposeParser {
    private let lines: [(indent: Int, text: String)]
    private var index = 0

    init(_ source: String) {
        var collected: [(Int, String)] = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = line.prefix { $0 == " " }.count
            collected.append((indent, trimmed))
        }
        lines = collected
    }

    mutating func parse() -> YAMLValue {
        parseNode(minIndent: 0)
    }

    private func peek() -> (indent: Int, text: String)? {
        index < lines.count ? lines[index] : nil
    }

    private mutating func parseNode(minIndent: Int) -> YAMLValue {
        guard let first = peek(), first.indent >= minIndent else { return .scalar("") }
        return first.text.hasPrefix("-") ? parseSequence(indent: first.indent) : parseMapping(indent: first.indent)
    }

    private mutating func parseMapping(indent: Int) -> YAMLValue {
        var pairs: [(String, YAMLValue)] = []
        while let line = peek(), line.indent == indent, !line.text.hasPrefix("-") {
            index += 1
            let (key, inline) = Self.splitKeyValue(line.text)
            pairs.append((key, childValue(inline: inline, parentIndent: indent)))
        }
        return .mapping(pairs)
    }

    private mutating func parseSequence(indent: Int) -> YAMLValue {
        var items: [YAMLValue] = []
        while let line = peek(), line.indent == indent, line.text.hasPrefix("-") {
            index += 1
            let afterDash = String(line.text.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            if afterDash.isEmpty {
                items.append(parseNode(minIndent: indent + 1))
            } else if Self.keyColonIndex(afterDash) != nil {
                items.append(inlineMappingItem(afterDash, dashIndent: indent))
            } else {
                items.append(.scalar(Self.unquote(afterDash)))
            }
        }
        return .sequence(items)
    }

    private mutating func inlineMappingItem(_ first: String, dashIndent: Int) -> YAMLValue {
        let innerIndent = dashIndent + 2
        var pairs: [(String, YAMLValue)] = []
        let (key, inline) = Self.splitKeyValue(first)
        pairs.append((key, childValue(inline: inline, parentIndent: innerIndent)))
        while let line = peek(), line.indent == innerIndent, !line.text.hasPrefix("-") {
            index += 1
            let (k, inlineValue) = Self.splitKeyValue(line.text)
            pairs.append((k, childValue(inline: inlineValue, parentIndent: innerIndent)))
        }
        return .mapping(pairs)
    }

    private mutating func childValue(inline: String?, parentIndent: Int) -> YAMLValue {
        if let inline, !inline.isEmpty {
            return .scalar(Self.unquote(inline))
        }
        if let next = peek(), next.indent > parentIndent {
            return parseNode(minIndent: parentIndent + 1)
        }
        return .scalar("")
    }

    private static func splitKeyValue(_ text: String) -> (String, String?) {
        guard let colon = keyColonIndex(text) else { return (text, nil) }
        let key = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
        let value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        return (key, value.isEmpty ? nil : value)
    }

    private static func keyColonIndex(_ text: String) -> String.Index? {
        var inSingle = false
        var inDouble = false
        var current = text.startIndex
        while current < text.endIndex {
            let character = text[current]
            if character == "\"" && !inSingle { inDouble.toggle() }
            else if character == "'" && !inDouble { inSingle.toggle() }
            else if character == ":" && !inSingle && !inDouble {
                let next = text.index(after: current)
                if next == text.endIndex || text[next] == " " { return current }
            }
            current = text.index(after: current)
        }
        return nil
    }

    static func unquote(_ text: String) -> String {
        guard text.count >= 2 else { return text }
        let first = text.first!
        let last = text.last!
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(text.dropFirst().dropLast())
        }
        return text
    }

    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        for character in text {
            if character == "\"" && !inSingle { inDouble.toggle() }
            else if character == "'" && !inDouble { inSingle.toggle() }
            else if character == " " && !inSingle && !inDouble {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
