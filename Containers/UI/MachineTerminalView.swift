import SwiftUI
import SwiftTerm

struct MachineTerminalView: NSViewRepresentable {
    let machineID: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        guard let binary = ContainerCLI.locateBinary() else {
            return terminal
        }
        terminal.startProcess(
            executable: binary.path,
            args: ["machine", "run", "--name", machineID],
            environment: nil,
            execName: nil
        )
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

struct MachineTerminalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let machineID: String

    var body: some View {
        NavigationStack {
            MachineTerminalView(machineID: machineID)
                .navigationTitle("Shell — \(machineID)")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
                }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
