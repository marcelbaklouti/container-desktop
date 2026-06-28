import SwiftUI

struct HelpTopic: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let systemImage: String
    let sections: [Section]

    struct Section {
        let heading: LocalizedStringKey
        let body: LocalizedStringKey
    }
}

struct HelpView: View {
    @State private var selection: HelpTopic.ID? = HelpTopic.all.first?.id

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.all, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.systemImage).tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
            .navigationTitle("Help")
        } detail: {
            if let topic = HelpTopic.all.first(where: { $0.id == selection }) {
                HelpTopicView(topic: topic)
            } else {
                ContentUnavailableView("Select a Topic", systemImage: "questionmark.circle")
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Label(topic.title, systemImage: topic.systemImage)
                    .font(.largeTitle.bold())
                    .labelStyle(.titleAndIcon)

                ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.heading)
                            .font(.title3.weight(.semibold))
                        Text(section.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: 660, alignment: .leading)
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(topic.title)
    }
}

extension HelpTopic {
    static let all: [HelpTopic] = [
        HelpTopic(
            id: "start",
            title: "Getting Started",
            systemImage: "hand.wave",
            sections: [
                .init(heading: "What Container Desktop is",
                      body: "Container Desktop is a native macOS interface for Apple’s container runtime. It manages containers, images, networks, volumes, and virtual machines by driving the container command-line tool, so anything you do here matches what the tool does in Terminal."),
                .init(heading: "Installing the runtime",
                      body: "If the container tool isn’t installed, the start screen offers to download and install Apple’s official, signed release for you, with a single administrator prompt. You can also install it yourself from github.com/apple/container."),
                .init(heading: "Starting the system",
                      body: "Containers run under a background system service that keeps them alive even when this app is closed. Use “Start Container System” on the start screen, or Start from the menu bar, to bring it up."),
            ]
        ),
        HelpTopic(
            id: "containers",
            title: "Containers",
            systemImage: "shippingbox",
            sections: [
                .init(heading: "Running a container",
                      body: "Click the + (Run Container) button to choose an image and set ports, environment variables, volumes, and resources. Give it a Project name to group it with related containers."),
                .init(heading: "Lifecycle",
                      body: "Right-click any container to Start, Stop, Restart, Kill, or Delete it. Quitting Container Desktop does not stop your containers — they keep running under the system service until you stop them or the service."),
                .init(heading: "Logs, stats, and a shell",
                      body: "Select a container to open the inspector, then switch tabs to follow live logs, watch CPU and memory charts, or open an interactive terminal inside the container."),
                .init(heading: "Published ports",
                      body: "Ports appear in the inspector. Click a port to open it in your browser, or copy its address. Running rows offer the same “Open” action in their context menu."),
            ]
        ),
        HelpTopic(
            id: "compose",
            title: "Compose Stacks",
            systemImage: "rectangle.3.group",
            sections: [
                .init(heading: "Launching a stack",
                      body: "Use “Launch Stack” in the Containers toolbar to pick a docker-compose.yml. Container Desktop reads the services, creates the named volumes and a project network, and starts each service in dependency order with live per-service progress."),
                .init(heading: "Grouping and totals",
                      body: "Containers are grouped by their Compose project. Each group header shows the combined CPU and memory of its running services, and the overall total appears beneath the Containers title."),
            ]
        ),
        HelpTopic(
            id: "images",
            title: "Images",
            systemImage: "square.stack.3d.up",
            sections: [
                .init(heading: "Pulling and building",
                      body: "Pull a pre-built image by reference, or Build one from a Dockerfile with live build output. Import and Export move images as .tar archives."),
                .init(heading: "Size, usage, and history",
                      body: "Each image shows its size and an “In Use” badge when a container references it. The inspector’s History section lists the build steps. Prune, in the More (⋯) menu, removes every image no container uses."),
            ]
        ),
        HelpTopic(
            id: "netvol",
            title: "Networks & Volumes",
            systemImage: "network",
            sections: [
                .init(heading: "Networks",
                      body: "Create networks to isolate groups of containers so they can reach each other by name. The built-in default network can’t be removed."),
                .init(heading: "Volumes",
                      body: "Volumes store data that outlives a container. Each row shows real disk usage against the allocated size. Deleting a volume permanently deletes its data — this can’t be undone."),
            ]
        ),
        HelpTopic(
            id: "machines",
            title: "Machines",
            systemImage: "server.rack",
            sections: [
                .init(heading: "Virtual machines",
                      body: "Machines are the Linux virtual machines that host your containers. Create additional machines with a custom image, CPU, and memory; set a default; open a shell; or edit a machine’s settings."),
            ]
        ),
        HelpTopic(
            id: "dns",
            title: "DNS & Hostnames",
            systemImage: "globe",
            sections: [
                .init(heading: "Local DNS domains",
                      body: "In System, create a local DNS domain. This needs administrator approval because it changes how your Mac resolves names. Containers started with that domain become reachable at <name>.<domain>."),
                .init(heading: "Container hostnames",
                      body: "Choose a DNS domain in the Run sheet to give a container a hostname. Its inspector then shows a copyable hostname you can open directly in the browser."),
                .init(heading: "Registries",
                      body: "Log in to a registry under Registries to pull and push private images. Your password is handled securely by the container tool and never passed on the command line."),
            ]
        ),
        HelpTopic(
            id: "menubar",
            title: "Menu Bar & Notifications",
            systemImage: "menubar.rectangle",
            sections: [
                .init(heading: "Menu bar",
                      body: "The menu bar item shows the running-container count and the combined CPU and memory, with quick Stop, Restart, and Open actions per container, plus Start and Stop for the system. It stays available even when the main window is closed."),
                .init(heading: "Notifications",
                      body: "Container Desktop can notify you when a container exits unexpectedly or when the system stops. Turn these on or off in Settings → Notifications."),
            ]
        ),
        HelpTopic(
            id: "updates",
            title: "Updates",
            systemImage: "arrow.down.circle",
            sections: [
                .init(heading: "Keeping the runtime current",
                      body: "Container Desktop’s version tracks the container runtime release it’s built for. System → Software Update shows the latest release from Apple and installs verified updates after an administrator prompt — Container Desktop only accepts packages signed and notarized by Apple."),
            ]
        ),
    ]
}
