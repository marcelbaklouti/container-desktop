import type { IconName } from "@/components/Icon";

export const site = {
  name: "Container Desktop",
  tagline: "The native Mac app for Apple's container runtime",
  description:
    "Container Desktop is a free, open source Mac app for Apple's container runtime. Run whole Compose stacks with combined live logs, manage containers, images, volumes, and networks, and move everything over from Docker in one click, data included.",
  url: "https://container-desktop.vercel.app",
  repo: "https://github.com/marcelbaklouti/container-desktop",
  releases: "https://github.com/marcelbaklouti/container-desktop/releases/latest",
  version: "1.0.5",
  requirements: "Apple Silicon · macOS 26 Tahoe or later",
};

export const nav = {
  links: [
    { label: "Features", href: "#features" },
    { label: "How it works", href: "#how-it-works" },
    { label: "Compare", href: "#compare" },
    { label: "FAQ", href: "#faq" },
  ],
};

export type Screenshot = {
  src?: string;
  label: string;
  width: number;
  height: number;
};

export const hero = {
  badge: "Free & open source · Built for macOS 26 on Apple Silicon",
  title: "Your containers, finally at home on the Mac.",
  subtitle:
    "Apple built a fast, lightweight container runtime into macOS. Container Desktop gives it the app it deserves: launch whole Compose stacks, read every service's logs in one place, and switch from Docker in a single click. Your data comes with you.",
  terminal: {
    command: "container run -d --name web -p 8080:80 nginx:latest",
    punchline: "You could type that. Or you could just click Run.",
  },
  screenshot: {
    src: "/screens/Container.png",
    label: "Containers",
    width: 2314,
    height: 1440,
  } as Screenshot,
};

export const proofPoints = [
  "100% Swift and SwiftUI, zero Electron",
  "No accounts, no tracking, no license fees",
  "Signed and notarized for Gatekeeper",
  "Apache 2.0, built in the open",
];

export type Highlight = { icon: IconName; title: string; body: string };

export const highlights: Highlight[] = [
  {
    icon: "arrow-right",
    title: "Leave Docker in an afternoon",
    body: "One click moves your containers over: images, settings, and the data in your volumes. The originals stay in Docker, stopped but never deleted.",
  },
  {
    icon: "layers",
    title: "Stacks that feel like one thing",
    body: "Your compose project is one unit here. Start it, stop it, relaunch it, and watch every service's logs stream together in color.",
  },
  {
    icon: "bolt",
    title: "Native, and it shows",
    body: "Real SwiftUI, Liquid Glass, and the keyboard shortcuts you expect. It opens fast, sips memory, and feels like it shipped with your Mac.",
  },
  {
    icon: "activity",
    title: "Always one glance away",
    body: "Live CPU and memory on every container, totals per project, and a menu bar that can stop a whole stack while your main window stays closed.",
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
    title: "Run your whole app as one unit.",
    body: "You do not think in five containers. You think in one app. The Stacks area works the same way: every Compose project appears as a single thing with live status, resource use, and controls for the whole stack or any single service. The combined log view streams every service together, each line colored by where it came from, searchable, filterable, and ready to pop out into its own window. No other app does this for Apple's runtime.",
    bullets: [
      "Combined live logs with per service colors and search",
      "Start, stop, and restart the stack or one service",
      "Relaunch any time from the remembered compose file",
    ],
    screenshot: { src: "/screens/Stacks.png", label: "Stacks", width: 2178, height: 1304 },
  },
  {
    id: "migrate",
    eyebrow: "Migration",
    icon: "arrow-right",
    title: "Switch from Docker without losing a thing.",
    body: "The scary part of switching runtimes is your data. Container Desktop handles it: pick the containers you want, and it brings the images, the configuration, and the actual contents of your named volumes across. Compose projects stay grouped. Every original stays in Docker, stopped as a fallback, and is only ever stopped after its replacement is confirmed running. There is nothing to lose by trying.",
    bullets: [
      "Volume data really moves, checked end to end",
      "Compose groups and labels carry over",
      "Originals are stopped, never deleted",
    ],
    screenshot: { src: "/screens/Migration.png", label: "Migrate from Docker", width: 1920, height: 1304 },
  },
  {
    id: "images",
    eyebrow: "Images",
    icon: "box",
    title: "Images, from pull to push.",
    body: "Pull by reference, build straight from a Dockerfile with the output streaming live, tag, push to any registry you are signed into, and import or export as tar archives. Every image shows its real size, its build history, and whether a container is actually using it, so pruning is a decision instead of a gamble.",
    bullets: [
      "Build from a Dockerfile with live output",
      "Push and pull private images with saved logins",
      "See what is in use before you prune",
    ],
    screenshot: { src: "/screens/Images.png", label: "Images", width: 2178, height: 1304 },
  },
  {
    id: "machines",
    eyebrow: "Machines",
    icon: "server",
    title: "The Linux VMs, without the mystery.",
    body: "Your containers run inside lightweight Linux virtual machines. Container Desktop puts them on screen: create one with the CPU, memory, and image you want, set a default, resize it later, and drop straight into a shell when you need to poke around.",
    bullets: [
      "Create VMs with exactly the resources you want",
      "Set the default machine in one click",
      "Open an interactive shell right from the list",
    ],
    screenshot: { src: "/screens/Machines.png", label: "Machines", width: 2178, height: 1304 },
  },
  {
    id: "system",
    eyebrow: "System & updates",
    icon: "shield",
    title: "From zero to running in one sitting.",
    body: "No runtime installed yet? Container Desktop downloads Apple's official release, verifies the signature, and installs it for you. After that it keeps both itself and the runtime current: updates download in the background, get checked against the developer's signature, and wait politely for you to click Restart to Update.",
    bullets: [
      "Guided, verified install of the container CLI",
      "Background app updates with one click to apply",
      "Local DNS domains for container hostnames",
    ],
    screenshot: { src: "/screens/System.png", label: "System", width: 2178, height: 1304 },
  },
];

export const manifesto =
  "No accounts. No tracking. No license fees. Just your containers, running the way Apple intended.";

export type Step = {
  number: string;
  title: string;
  body: string;
};

export const howItWorks = {
  title: "Up and running in three steps",
  subtitle: "From an empty Mac to a running stack, usually in under five minutes.",
  steps: [
    {
      number: "01",
      title: "Install in a minute",
      body: "Download the DMG, drag it to Applications, and open it. If Apple's container runtime is missing, the app installs the official signed release for you after one admin prompt.",
    },
    {
      number: "02",
      title: "Bring your containers",
      body: "Coming from Docker? Click Migrate and pick what moves: images, settings, and volume data come along. Starting fresh? Launch a compose file or run a single image.",
    },
    {
      number: "03",
      title: "Manage it like a Mac app",
      body: "Stacks, live logs, stats, and a menu bar that keeps working with the window closed. Keyboard shortcuts everywhere, and errors that offer the fix instead of an apology.",
    },
  ] as Step[],
};

export type CompareRow = {
  label: string;
  cli: boolean | null;
  dockerDesktop: boolean | null;
  containerDesktop: boolean;
};

export const compare = {
  title: "Why not just use the terminal?",
  subtitle:
    "You still can, any time. Every action in Container Desktop maps to a container command, so the app and your terminal always agree. Here is what the app adds, honestly.",
  columns: ["The container CLI", "Docker Desktop", "Container Desktop"],
  rows: [
    { label: "Built for Apple's container runtime", cli: true, dockerDesktop: false, containerDesktop: true },
    { label: "Native Mac app, no Electron", cli: null, dockerDesktop: false, containerDesktop: true },
    { label: "Compose stacks on Apple's runtime", cli: false, dockerDesktop: false, containerDesktop: true },
    { label: "One click migration from Docker, data included", cli: false, dockerDesktop: false, containerDesktop: true },
    { label: "Visual logs, stats, and inspectors", cli: false, dockerDesktop: true, containerDesktop: true },
    { label: "Free for commercial use at any company size", cli: true, dockerDesktop: false, containerDesktop: true },
  ] as CompareRow[],
  footnote:
    "Docker Desktop is excellent software for the Docker engine. Container Desktop exists for people who want Apple's runtime with the same comfort.",
};

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
    body: "Give related containers their own network so they find each other by name. The built in one stays protected.",
    screenshot: { src: "/screens/Networks.png", label: "Networks", width: 2178, height: 1304 },
  },
  {
    icon: "drive",
    title: "Volumes",
    body: "See the real disk usage of every volume and exactly which containers mount it, one click away.",
    screenshot: { src: "/screens/Volumes.png", label: "Volumes", width: 2178, height: 1304 },
  },
  {
    icon: "key",
    title: "Registries",
    body: "Sign in once to pull and push private images. Your password goes to the keychain, never the command line.",
    screenshot: { src: "/screens/Registries.png", label: "Registries", width: 2178, height: 1304 },
  },
  {
    icon: "hammer",
    title: "Builder",
    body: "The build service starts itself when a build needs it. Watch it, stop it, or forget it exists.",
    screenshot: { src: "/screens/Builder.png", label: "Builder", width: 2178, height: 1304 },
  },
];

export type Capability = { icon: IconName; title: string; body: string };

export const capabilities: Capability[] = [
  { icon: "bolt", title: "Getting started", body: "Install the runtime, start the system, and run your first container." },
  { icon: "arrow-right", title: "Migrate from Docker", body: "Move containers over in one click: images, settings, and volume data." },
  { icon: "box", title: "Containers", body: "Run, inspect, duplicate, copy as a command; searchable logs, stats, shell, ports." },
  { icon: "layers", title: "Stacks", body: "Manage Compose projects as one unit with combined logs and per service controls." },
  { icon: "network", title: "Networks & volumes", body: "Isolate containers, store data that outlives them, and see what uses what." },
  { icon: "server", title: "Machines", body: "Manage the Linux VMs, set a default, and open an interactive shell." },
  { icon: "globe", title: "DNS & hostnames", body: "Create local DNS domains and reach containers at name.domain." },
  { icon: "menubar", title: "Menu bar & notifications", body: "Quick actions per stack and container; alerts when something exits." },
  { icon: "shield", title: "Updates", body: "The app updates itself in the background. One click to restart and apply." },
];

export type FAQItem = { question: string; answer: string };

export const faq = {
  title: "Questions, answered",
  subtitle: "The things people ask before they hit Download.",
  items: [
    {
      question: "What is Container Desktop?",
      answer:
        "Container Desktop is a free, open source Mac app that gives Apple's container runtime a full graphical interface. You get containers, images, volumes, networks, virtual machines, Compose stacks with combined live logs, and a one click migration from Docker, all in a native SwiftUI app.",
    },
    {
      question: "Is Container Desktop really free?",
      answer:
        "Yes. It is open source under the Apache 2.0 license, free for personal and commercial use at any company size, with no accounts, no subscriptions, and no feature gates. The code is public on GitHub.",
    },
    {
      question: "Can I run my docker-compose.yml on Apple's container runtime?",
      answer:
        "Yes. Open your compose file with Launch Stack and Container Desktop creates the volumes and network, builds services that declare build sections, and starts everything in dependency order. Variable interpolation and .env files work the way you expect, and the whole stack then appears as one unit in the Stacks area.",
    },
    {
      question: "How does the Docker migration work?",
      answer:
        "Pick the containers you want to move and Container Desktop does the rest: images transfer directly, named volumes are recreated and their data is copied over, and each container is rebuilt with its ports, environment, mounts, and labels. Your Docker originals are stopped only after their replacement is running, and they are never deleted, so you can switch back at any point.",
    },
    {
      question: "How is this different from Docker Desktop or OrbStack?",
      answer:
        "Docker Desktop and OrbStack run the Docker engine. Container Desktop is built for Apple's own container runtime, the one Apple ships for macOS. If you want to use Apple's runtime with the comfort of a real app, this is the tool. It is also fully native SwiftUI rather than a web view, and free regardless of company size.",
    },
    {
      question: "What do I need to run it?",
      answer:
        "A Mac with Apple Silicon running macOS 26 Tahoe or later. You do not need to install anything else first: if Apple's container CLI is missing, the app offers to install the official signed release for you.",
    },
    {
      question: "Is Container Desktop made by Apple?",
      answer:
        "No. Container Desktop is an independent open source project and is not affiliated with, endorsed by, or sponsored by Apple. It builds on the container runtime that Apple publishes as open source.",
    },
    {
      question: "Is it safe to install?",
      answer:
        "The app is signed with a registered Apple Developer ID and notarized by Apple, so Gatekeeper verifies every download. Updates are checked against the same signature before they install, the runtime installer only accepts packages signed by Apple, and the entire source code is public if you want to see for yourself.",
    },
  ] as FAQItem[],
};

export const download = {
  title: "Give your containers a better home.",
  subtitle:
    "One small download, no account, and your first stack can be running in minutes. If it is not for you, your containers never even notice.",
  note: "The DMG is hosted on GitHub Releases with its SHA-256 checksum in the notes.",
};

export const legal = {
  short: "Not affiliated with Apple Inc.",
  long: "Container Desktop is an independent, open-source project and is not affiliated with, endorsed by, or sponsored by Apple Inc. Apple, macOS, and Apple Silicon are trademarks of Apple Inc. Container Desktop is native in look and feel but does not use Apple's logo or trade dress.",
};
