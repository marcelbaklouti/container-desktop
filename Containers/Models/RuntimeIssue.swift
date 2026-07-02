import Foundation

nonisolated struct RuntimeIssue: Identifiable {
    nonisolated enum Remedy: Equatable {
        case stopContainers([String])
        case stopAndDeleteContainer(String)
        case revealContainers([String])
        case startDaemon
        case none
    }

    let id = UUID()
    let title: String
    let reason: String
    let remedyLabel: String?
    let remedy: Remedy
    let rawDetails: String?

    init(title: String, reason: String, remedyLabel: String? = nil, remedy: Remedy = .none, rawDetails: String? = nil) {
        self.title = title
        self.reason = reason
        self.remedyLabel = remedyLabel
        self.remedy = remedy
        self.rawDetails = rawDetails
    }

    static func plain(title: String, reason: String) -> RuntimeIssue {
        RuntimeIssue(title: title, reason: reason)
    }
}

/// Turns a RuntimeError plus what the app was doing into a titled, human-readable issue with a
/// recovery action. The stderr patterns are matched against real CLI 1.0.0 output.
nonisolated enum IssueMapper {
    nonisolated enum Context {
        case deleteContainer(id: String)
        case deleteVolume(name: String, mountedBy: [String])
        case deleteNetwork(name: String, attachedTo: [String])
        case deleteImage(reference: String)
        case runContainer
        case generic(actionTitle: String)
    }

    static func issue(for error: any Error, context: Context) -> RuntimeIssue {
        guard let runtimeError = error as? RuntimeError else {
            return RuntimeIssue(title: fallbackTitle(for: context), reason: error.localizedDescription)
        }
        switch runtimeError {
        case .binaryNotFound:
            return RuntimeIssue(
                title: String(localized: "The container Tool Is Missing"),
                reason: String(localized: "The container command-line tool could not be found. Install it from the start screen.")
            )
        case .daemonNotRunning:
            return RuntimeIssue(
                title: String(localized: "The Container System Is Stopped"),
                reason: String(localized: "Nothing can run until the container system starts."),
                remedyLabel: String(localized: "Start Container System"),
                remedy: .startDaemon
            )
        case .commandFailed, .decodingFailed:
            break
        }

        let message = runtimeError.localizedMessage
        let details = detailPayload(for: runtimeError)

        if message.hasPrefix("A published port is already in use") || message.localizedCaseInsensitiveContains("address already in use") || message.contains("errno: 48") {
            return RuntimeIssue(
                title: String(localized: "A Port Is Already in Use"),
                reason: message,
                remedyLabel: String(localized: "Show Running Containers"),
                remedy: .revealContainers([]),
                rawDetails: details
            )
        }

        switch context {
        case let .deleteContainer(id) where message.contains("is running and can not be deleted") || message.contains("invalidState"):
            return RuntimeIssue(
                title: String(localized: "“\(id)” Is Still Running"),
                reason: String(localized: "A container has to stop before it can be deleted."),
                remedyLabel: String(localized: "Stop and Delete"),
                remedy: .stopAndDeleteContainer(id),
                rawDetails: details
            )
        case let .deleteVolume(name, mountedBy) where message.localizedCaseInsensitiveContains("in use"):
            let reason = mountedBy.isEmpty
                ? String(localized: "A container is using this volume. Stop that container, then delete the volume.")
                : String(localized: "It’s mounted by \(mountedBy.formatted(.list(type: .and))). Stop \(mountedBy.count == 1 ? "it" : "them") first, then delete the volume.")
            return RuntimeIssue(
                title: String(localized: "“\(name)” Is in Use"),
                reason: reason,
                remedyLabel: mountedBy.isEmpty ? nil : String(localized: "Show \(mountedBy.count == 1 ? "Container" : "Containers")"),
                remedy: mountedBy.isEmpty ? .none : .revealContainers(mountedBy),
                rawDetails: details
            )
        case let .deleteNetwork(name, attachedTo) where message.contains("referring containers") || message.localizedCaseInsensitiveContains("in use"):
            let attached = attachedTo.isEmpty ? parseReferringContainers(from: message) : attachedTo
            let reason = attached.isEmpty
                ? String(localized: "A container is attached to this network. Delete that container, then delete the network.")
                : String(localized: "\(attached.formatted(.list(type: .and))) \(attached.count == 1 ? "is" : "are") attached to it. Delete \(attached.count == 1 ? "that container" : "those containers"), then delete the network.")
            return RuntimeIssue(
                title: String(localized: "“\(name)” Is in Use"),
                reason: reason,
                remedyLabel: attached.isEmpty ? nil : String(localized: "Show \(attached.count == 1 ? "Container" : "Containers")"),
                remedy: attached.isEmpty ? .none : .revealContainers(attached),
                rawDetails: details
            )
        default:
            return RuntimeIssue(title: fallbackTitle(for: context), reason: message, rawDetails: details)
        }
    }

    private static func fallbackTitle(for context: Context) -> String {
        switch context {
        case .deleteContainer: String(localized: "Couldn’t Delete the Container")
        case .deleteVolume: String(localized: "Couldn’t Delete the Volume")
        case .deleteNetwork: String(localized: "Couldn’t Delete the Network")
        case .deleteImage: String(localized: "Couldn’t Delete the Image")
        case .runContainer: String(localized: "Couldn’t Run the Container")
        case let .generic(actionTitle): actionTitle
        }
    }

    private static func detailPayload(for error: RuntimeError) -> String? {
        switch error {
        case let .commandFailed(arguments, exitCode, message):
            "container \(arguments.joined(separator: " "))\nexit code \(exitCode)\n\(message)"
        case let .decodingFailed(arguments, message):
            "container \(arguments.joined(separator: " "))\n\(message)"
        case .binaryNotFound, .daemonNotRunning:
            nil
        }
    }

    private static func parseReferringContainers(from message: String) -> [String] {
        guard let range = message.range(of: "referring containers: ") else { return [] }
        let tail = message[range.upperBound...]
        let list = tail.prefix { $0 != "\"" && $0 != "]" && !$0.isNewline }
        return list.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
