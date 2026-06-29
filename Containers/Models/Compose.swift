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

    func containerIdentifier(in project: ComposeProject) -> String {
        containerName ?? name
    }

    func runArguments(in project: ComposeProject) -> [String] {
        var args = ["run", "-d", "--name", containerIdentifier(in: project), "--network", project.networkName]
        args += ["--label", "\(Container.projectLabelKey)=\(project.name)"]
        args += ["--label", "com.docker.compose.service=\(name)"]
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
            args += ["--label", "\(key)=\(value)"]
        }
        for variable in environment { args += ["-e", variable] }
        for port in ports { args += ["-p", port] }
        for volume in volumes { args += ["-v", volume] }
        if let image {
            args.append("--")
            args.append(image)
            args += command
        }
        return args
    }
}

nonisolated struct ComposeProject: Equatable, Identifiable {
    let name: String
    let services: [ComposeService]
    let namedVolumes: [String]

    var id: String { name }

    var networkName: String {
        String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    /// Reads a compose file plus a sibling `.env`, then parses with interpolation. Shell
    /// environment overrides `.env` values, matching Docker Compose precedence.
    static func load(from url: URL) -> ComposeProject? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let directory = url.deletingLastPathComponent()
        var environment = loadDotEnv(in: directory)
        environment.merge(ProcessInfo.processInfo.environment) { _, shell in shell }
        return parse(text, defaultName: directory.lastPathComponent, environment: environment)
    }

    static func loadDotEnv(in directory: URL) -> [String: String] {
        guard let text = try? String(contentsOf: directory.appendingPathComponent(".env"), encoding: .utf8) else { return [:] }
        var values: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equals]).trimmingCharacters(in: .whitespaces)
            let value = ComposeParser.unquote(String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces))
            if !key.isEmpty { values[key] = value }
        }
        return values
    }

    static func parse(_ source: String, defaultName: String, environment: [String: String] = [:]) -> ComposeProject? {
        var parser = ComposeParser(source)
        let interpolated = ComposeInterpolation.interpolate(parser.parse(), environment: environment)
        guard case let .mapping(root) = interpolated else { return nil }

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
                return normalizePortSpec(text)
            case let .mapping(pairs):
                guard let target = pairs.scalar("target") else { return nil }
                // Long syntax publishes to the host only when `published` is set;
                // a bare `target` is expose-only and must not become a `-p` mapping.
                guard let published = pairs.scalar("published") else { return nil }
                return "\(published):\(target)"
            default:
                return nil
            }
        }
    }

    /// `container run -p` requires `[host-ip:]host-port:container-port[/proto]`, so the bare
    /// container port that Compose short syntax allows (`"3000"`, `"3000/udp"`) is rejected —
    /// mirror it to `host:container`. Already-mapped values pass through unchanged.
    nonisolated private static func normalizePortSpec(_ text: String) -> String {
        let (body, proto) = splitProtocol(text)
        guard !body.contains(":") else { return text }
        guard !body.isEmpty, body.allSatisfy(\.isNumber) else { return text }
        return proto.map { "\(body):\(body)/\($0)" } ?? "\(body):\(body)"
    }

    nonisolated private static func splitProtocol(_ text: String) -> (String, String?) {
        guard let slash = text.lastIndex(of: "/") else { return (text, nil) }
        return (String(text[..<slash]), String(text[text.index(after: slash)...]))
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

/// Docker Compose variable interpolation: `$VAR`, `${VAR}`, `${VAR:-default}`, `${VAR-default}`,
/// `${VAR:?err}`, `${VAR?err}`, `${VAR:+alt}`, `${VAR+alt}`, `$$` (a literal `$`), and nested
/// `${VAR:-${OTHER}}`. Applied to scalar VALUES only (keys are left untouched).
nonisolated enum ComposeInterpolation {
    static func interpolate(_ value: YAMLValue, environment: [String: String]) -> YAMLValue {
        switch value {
        case let .scalar(text):
            return .scalar(expand(text, environment: environment))
        case let .sequence(items):
            return .sequence(items.map { interpolate($0, environment: environment) })
        case let .mapping(pairs):
            return .mapping(pairs.map { ($0.0, interpolate($0.1, environment: environment)) })
        }
    }

    static func expand(_ text: String, environment: [String: String]) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0
        while index < chars.count {
            let character = chars[index]
            guard character == "$" else { result.append(character); index += 1; continue }
            let next = index + 1
            if next < chars.count, chars[next] == "$" {
                result.append("$"); index += 2; continue
            }
            if next < chars.count, chars[next] == "{" {
                let (expression, after) = readBraced(chars, from: next + 1)
                result += evaluate(expression, environment: environment)
                index = after; continue
            }
            let (name, after) = readName(chars, from: next)
            if name.isEmpty {
                result.append(character); index += 1; continue
            }
            result += environment[name] ?? ""
            index = after
        }
        return result
    }

    private static func readName(_ chars: [Character], from start: Int) -> (String, Int) {
        var index = start
        var name = ""
        while index < chars.count {
            let character = chars[index]
            if character == "_" || character.isLetter || (!name.isEmpty && character.isNumber) {
                name.append(character)
                index += 1
            } else {
                break
            }
        }
        return (name, index)
    }

    private static func readBraced(_ chars: [Character], from start: Int) -> (String, Int) {
        var index = start
        var depth = 1
        var expression = ""
        while index < chars.count {
            let character = chars[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 { index += 1; break }
            }
            expression.append(character)
            index += 1
        }
        return (expression, index)
    }

    private static func evaluate(_ expression: String, environment: [String: String]) -> String {
        let chars = Array(expression)
        let (name, rest) = readName(chars, from: 0)
        guard !name.isEmpty else { return "" }
        let value = environment[name]
        let isSet = value != nil
        let isNonEmpty = !(value ?? "").isEmpty
        guard rest < chars.count else { return value ?? "" }

        let operatorChars = Array(chars[rest...])
        let (op, word) = splitOperator(operatorChars, environment: environment)
        switch op {
        case ":-": return isNonEmpty ? value! : word
        case "-": return isSet ? value! : word
        case ":+": return isNonEmpty ? word : ""
        case "+": return isSet ? word : ""
        default: return value ?? ""   // ${VAR:?err}/${VAR?err}: Compose errors; we substitute the value or empty
        }
    }

    private static func splitOperator(_ operatorChars: [Character], environment: [String: String]) -> (op: String, word: String) {
        if operatorChars.count >= 2 {
            let two = String(operatorChars[0...1])
            if two == ":-" || two == ":?" || two == ":+" {
                return (two, expand(String(operatorChars[2...]), environment: environment))
            }
        }
        if let first = operatorChars.first, first == "-" || first == "?" || first == "+" {
            return (String(first), expand(String(operatorChars.dropFirst()), environment: environment))
        }
        return ("", "")
    }
}
