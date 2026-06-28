import type { ReactNode } from "react";

export type IconName =
  | "bolt"
  | "layers"
  | "activity"
  | "terminal"
  | "box"
  | "network"
  | "drive"
  | "server"
  | "key"
  | "hammer"
  | "globe"
  | "menubar"
  | "download"
  | "github"
  | "arrow-right"
  | "check"
  | "shield";

const strokeIcons: Partial<Record<IconName, ReactNode>> = {
  bolt: <path d="M13 2 4.5 13.5H11l-1 8.5L19.5 10H13l1-8Z" />,
  layers: (
    <>
      <path d="m12 3 9 5-9 5-9-5 9-5Z" />
      <path d="m3 13 9 5 9-5" />
      <path d="m3 17.5 9 5 9-5" />
    </>
  ),
  activity: <path d="M3 12h4l3 8 4-17 3 9h4" />,
  terminal: (
    <>
      <rect x="2.5" y="3.5" width="19" height="17" rx="2.5" />
      <path d="m6.5 9 3.5 3.5-3.5 3.5" />
      <path d="M13 16h4.5" />
    </>
  ),
  box: (
    <>
      <path d="M12 3 3.5 7.8v8.4L12 21l8.5-4.8V7.8L12 3Z" />
      <path d="m3.7 8 8.3 4.7 8.3-4.7" />
      <path d="M12 12.7V21" />
    </>
  ),
  network: (
    <>
      <circle cx="12" cy="5" r="2.5" />
      <circle cx="5" cy="19" r="2.5" />
      <circle cx="19" cy="19" r="2.5" />
      <path d="M12 7.5v3.5M12 11 6.6 16.6M12 11l5.4 5.6" />
    </>
  ),
  drive: (
    <>
      <ellipse cx="12" cy="6" rx="7.5" ry="3" />
      <path d="M4.5 6v12c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3V6" />
      <path d="M4.5 12c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3" />
    </>
  ),
  server: (
    <>
      <rect x="3" y="4" width="18" height="7" rx="2" />
      <rect x="3" y="13" width="18" height="7" rx="2" />
      <path d="M7 7.5h.01M7 16.5h.01" />
    </>
  ),
  key: (
    <>
      <circle cx="7.5" cy="15.5" r="4.5" />
      <path d="m10.7 12.3 8.3-8.3M16 6l2.5 2.5M14 8l2.5 2.5" />
    </>
  ),
  hammer: (
    <>
      <path d="m15 12-8.37 8.37a1 1 0 1 1-3-3L12 9" />
      <path d="m18 15 4-4" />
      <path d="m21.5 11.5-2-2A2 2 0 0 1 19 8.2V7l-2.3-2.3a6 6 0 0 0-4.2-1.7L9 3l.9.8A6 6 0 0 1 12 8.4V10l2 2h1.2a2 2 0 0 1 1.4.6l1.9 1.9" />
    </>
  ),
  globe: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3c2.5 2.5 3.8 5.7 3.8 9S14.5 18.5 12 21C9.5 18.5 8.2 15.3 8.2 12 8.2 8.7 9.5 5.5 12 3Z" />
    </>
  ),
  menubar: (
    <>
      <rect x="2.5" y="4.5" width="19" height="15" rx="2.5" />
      <path d="M2.5 9.5h19M6 7h.01M9 7h.01" />
    </>
  ),
  download: (
    <>
      <path d="M12 3.5v11" />
      <path d="m7.5 10.5 4.5 4.5 4.5-4.5" />
      <path d="M4.5 20.5h15" />
    </>
  ),
  "arrow-right": <path d="M4.5 12h15m-6-6 6 6-6 6" />,
  check: <path d="m4.5 12.5 4.5 4.5 10.5-10.5" />,
  shield: (
    <>
      <path d="M12 3 5 6v6c0 4 3 6.7 7 9 4-2.3 7-5 7-9V6l-7-3Z" />
      <path d="m9 12 2 2 4.5-4.5" />
    </>
  ),
};

const filledIcons: Partial<Record<IconName, ReactNode>> = {
  github: (
    <path d="M12 2C6.48 2 2 6.48 2 12c0 4.42 2.87 8.17 6.84 9.5.5.09.68-.22.68-.48l-.01-1.7c-2.78.6-3.37-1.34-3.37-1.34-.46-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.89 1.52 2.34 1.08 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.56-1.11-4.56-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02a9.56 9.56 0 0 1 5 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85l-.01 2.75c0 .27.18.58.69.48A10 10 0 0 0 22 12c0-5.52-4.48-10-10-10Z" />
  ),
};

export function Icon({
  name,
  size = 24,
  className,
}: {
  name: IconName;
  size?: number;
  className?: string;
}) {
  const isFilled = name in filledIcons;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={isFilled ? "currentColor" : "none"}
      stroke={isFilled ? "none" : "currentColor"}
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {isFilled ? filledIcons[name] : strokeIcons[name]}
    </svg>
  );
}
