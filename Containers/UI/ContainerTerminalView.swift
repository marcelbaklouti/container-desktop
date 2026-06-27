import SwiftUI
import SwiftTerm

struct ContainerTerminalView: NSViewRepresentable {
    let containerID: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        guard let binary = ContainerCLI.locateBinary() else {
            return terminal
        }
        terminal.startProcess(
            executable: binary.path,
            args: ["exec", "--interactive", "--tty", containerID, "sh"],
            environment: nil,
            execName: nil
        )
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
