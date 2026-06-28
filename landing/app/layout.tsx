import type { Metadata } from "next";
import "./globals.css";

const description =
  "Container Desktop is a native macOS app for Apple's container runtime — run, inspect, and manage containers, images, volumes, networks, machines, and Compose stacks, with live stats and a menu bar.";

export const metadata: Metadata = {
  title: "Container Desktop — A native Mac app for Apple's container runtime",
  description,
  openGraph: {
    title: "Container Desktop",
    description,
    type: "website",
  },
  icons: { icon: "/favicon.ico" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
