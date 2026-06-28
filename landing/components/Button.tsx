import Link from "next/link";
import { Icon, type IconName } from "./Icon";
import type { ReactNode } from "react";

type Variant = "primary" | "secondary";

export function Button({
  href,
  children,
  variant = "primary",
  icon,
  external,
  className,
}: {
  href: string;
  children: ReactNode;
  variant?: Variant;
  icon?: IconName;
  external?: boolean;
  className?: string;
}) {
  const base =
    "inline-flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-semibold transition-transform duration-200 ease-apple hover:-translate-y-0.5 focus-visible:-translate-y-0.5";
  const styles =
    variant === "primary"
      ? "bg-accent text-white shadow-lg shadow-accent/25 hover:bg-accent-soft"
      : "glass text-fg hover:bg-white/[0.07]";
  const externalProps = external
    ? { target: "_blank", rel: "noreferrer" }
    : {};
  return (
    <Link
      href={href}
      className={`${base} ${styles} ${className ?? ""}`}
      {...externalProps}
    >
      {icon && <Icon name={icon} size={18} />}
      {children}
    </Link>
  );
}
