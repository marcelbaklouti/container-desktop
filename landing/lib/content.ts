import type { IconName } from "@/components/Icon";

export const site = {
  name: "Container Desktop",
  tagline: "A native Mac GUI for Apple's container runtime",
  description:
    "Container Desktop is a native macOS GUI for Apple's container runtime — manage whole Compose stacks with combined live logs, run and inspect containers, images, volumes, networks, and machines, and move over from Docker in one click, data included.",
  url: "https://container-desktop.vercel.app",
  repo: "https://github.com/marcelbaklouti/container-desktop",
  releases: "https://github.com/marcelbaklouti/container-desktop/releases/latest",
  version: "1.0.5",
  requirements: "Apple Silicon · macOS 26 Tahoe or later",
};

export const nav = {
  links: [
    { label: "Features", href: "#features" },
    { label: "What you can do", href: "#capabilities" },
    { label: "Download", href: "#download" },
  ],
};

export type Screenshot = {
  src?: string;
  label: string;
  width: number;
  height: number;
};

export const hero = {
  badge: "Apple Silicon · macOS 26 · Free & open source",
  title: "The Apple container GUI for your Mac.",
  subtitle:
    "Container Desktop is a native SwiftUI app for Apple's container runtime. Manage whole Compose stacks as one unit — combined live logs included — inspect containers, images, volumes, networks, and machines, and switch from Docker in one click, volume data included.",
  screenshot: {
    src: "/screens/Container.png",
    label: "Containers",
    width: 2314,
    height: 1440,
  } as Screenshot,
};

export type Highlight = { icon: IconName; title: string; body: string };

export const highlights: Highlight[] = [
  {
    icon: "arrow-right",
    title: "Migrate from Docker",
    body: "Move containers over in one click — images, settings, and volume data. Originals are stopped, never deleted.",
  },
  {
    icon: "bolt",
    title: "Native, not a wrapper",
    body: "Built in SwiftUI with Liquid Glass — no Electron. Every action maps to the container CLI.",
  },
  {
    icon: "layers",
    title: "Stacks, first-class",
    body: "Every Compose project is one unit — combined color-coded logs, per-service controls, one-click relaunch.",
  },
  {
    icon: "activity",
    title: "Live stats & menu bar",
    body: "Real-time CPU and memory on every container, per-project totals, and a menu-bar summary.",
  },
];

export type FeatureSection = {
  id: string;
  eyebrow: string;
  icon: IconName;
  title: string;
  body: string;
  bullets: string[];
  screenshot: Screenshot;
};

export const features: FeatureSection[] = [
  {
    id: "stacks",
    eyebrow: "Stacks",
    icon: "layers",
    title: "Your whole app, as one unit.",
    body: "The Stacks area treats every Compose project the way you think about it: one thing. See all services with live status and resource use, start, stop, or relaunch the whole stack, and read every service's output in one combined, color-coded live log — searchable, filterable per service, and detachable into its own window. No other GUI for Apple's runtime does this.",
    bullets: [
      "Combined live logs with per-service colors and search",
      "Start, stop, restart — per service or the whole stack",
      "Relaunch from the remembered compose file",
    ],
    screenshot: { label: "Stacks", width: 2402, height: 1528 },
  },
  {
    id: "migrate",
    eyebrow: "Migration",
    icon: "arrow-right",
    title: "Leave Docker Desktop in one afternoon.",
    body: "Already on Docker? Container Desktop finds your containers, groups them by Compose project, and moves the ones you pick — the image, the configuration, and the data in named volumes all come along. Each container's Docker original is stopped only once its replacement is running, and never deleted, so there's nothing to lose by trying.",
    bullets: [
      "Pick containers — Compose groups carry over",
      "Images and volume data move with them",
      "Originals are stopped, never deleted",
    ],
    screenshot: { src: "/screens/Migration.png", label: "Migrate from Docker", width: 2144, height: 1528 },
  },
  {
    id: "images",
    eyebrow: "Images",
    icon: "box",
    title: "Images, end to end.",
    body: "Pull by reference, build from a Dockerfile with streaming output, tag and push to registries, and import or export as .tar. Every image shows its size, build history, and whether a container is using it.",
    bullets: [
      "Build from a Dockerfile with live logs",
      "Push and pull private images via saved logins",
      "Import/export .tar, view history, prune unused",
    ],
    screenshot: { src: "/screens/Images.png", label: "Images", width: 2402, height: 1528 },
  },
  {
    id: "machines",
    eyebrow: "Machines",
    icon: "server",
    title: "The Linux VMs behind your containers.",
    body: "Container Desktop manages the virtual machines that host your containers — create them with custom CPU, memory, and image, set a default, reconfigure on the fly, and drop straight into a shell.",
    bullets: [
      "Create VMs with custom resources",
      "Set the default machine in a click",
      "Open an interactive shell over machine run",
    ],
    screenshot: { src: "/screens/Machines.png", label: "Machines", width: 2402, height: 1528 },
  },
  {
    id: "system",
    eyebrow: "System & updates",
    icon: "shield",
    title: "Set up the runtime — and keep it current.",
    body: "Don't have the container CLI yet? Container Desktop installs Apple's official, signed release for you. Manage local DNS domains, watch disk usage, and update both the runtime and the app — only ever from packages signed and notarized by Apple.",
    bullets: [
      "Guided, verified install of the container CLI",
      "In-app updates for the runtime and the app",
      "Local DNS domains for container hostnames",
    ],
    screenshot: { src: "/screens/System.png", label: "System", width: 2402, height: 1528 },
  },
];

export type BentoCard = {
  icon: IconName;
  title: string;
  body: string;
  screenshot: Screenshot;
};

export const bento: BentoCard[] = [
  {
    icon: "network",
    title: "Networks",
    body: "Isolate containers so they reach each other by name. The built-in default network is protected.",
    screenshot: { src: "/screens/Networks.png", label: "Networks", width: 2402, height: 1528 },
  },
  {
    icon: "drive",
    title: "Volumes",
    body: "Named volumes with real on-disk usage — see what each one actually uses, not just its cap.",
    screenshot: { src: "/screens/Volumes.png", label: "Volumes", width: 2402, height: 1528 },
  },
  {
    icon: "key",
    title: "Registries",
    body: "Sign in to pull and push private images. Your password never touches the command line.",
    screenshot: { src: "/screens/Registries.png", label: "Registries", width: 2402, height: 1528 },
  },
  {
    icon: "hammer",
    title: "Builder",
    body: "Start, stop, and watch the build service that powers your image builds.",
    screenshot: { src: "/screens/Builder.png", label: "Builder", width: 2402, height: 1528 },
  },
];

export type Capability = { icon: IconName; title: string; body: string };

export const capabilities: Capability[] = [
  { icon: "bolt", title: "Getting started", body: "Install the runtime, start the system, and run your first container." },
  { icon: "arrow-right", title: "Migrate from Docker", body: "Move containers over in one click — images, settings, and volume data." },
  { icon: "box", title: "Containers", body: "Run, inspect, duplicate, copy-as-command; searchable logs, stats, shell, ports." },
  { icon: "layers", title: "Stacks", body: "Manage Compose projects as one unit — combined logs, per-service controls, relaunch." },
  { icon: "box", title: "Images", body: "Pull, build, tag, push, import/export, view history, and prune." },
  { icon: "network", title: "Networks & volumes", body: "Isolate containers and store data that outlives them, with real usage." },
  { icon: "server", title: "Machines", body: "Manage the Linux VMs, set a default, and open an interactive shell." },
  { icon: "globe", title: "DNS & hostnames", body: "Create local DNS domains and reach containers at name.domain." },
  { icon: "menubar", title: "Menu bar & notifications", body: "Quick actions from the menu bar; alerts for exits and daemon stops." },
  { icon: "shield", title: "Updates", body: "The app updates itself in the background — one click to restart and apply." },
];

export const legal = {
  short: "Not affiliated with Apple Inc.",
  long: "Container Desktop is an independent, open-source project and is not affiliated with, endorsed by, or sponsored by Apple Inc. Apple, macOS, and Apple Silicon are trademarks of Apple Inc. Container Desktop is native in look and feel but does not use Apple's logo or trade dress.",
};
