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
  compact,
  className,
}: {
  href: string;
  children: ReactNode;
  variant?: Variant;
  icon?: IconName;
  external?: boolean;
  compact?: boolean;
  className?: string;
}) {
  const base =
    "group inline-flex items-center justify-center rounded-full text-sm font-semibold transition-all duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] hover:-translate-y-0.5 focus-visible:-translate-y-0.5 active:scale-[0.98] active:translate-y-0";
  const size = compact
    ? icon
      ? "gap-2 pl-4 pr-1.5 py-1.5"
      : "gap-2 px-4 py-2"
    : icon
      ? "gap-2.5 pl-6 pr-2 py-2"
      : "gap-2.5 px-6 py-3";
  const styles =
    variant === "primary"
      ? "bg-accent text-white shadow-[0_8px_32px_rgba(10,132,255,0.35)] hover:bg-accent-soft"
      : "glass text-fg hover:bg-white/[0.07]";
  const iconWrap =
    variant === "primary"
      ? "bg-white/18 text-white"
      : "bg-white/8 text-fg-muted group-hover:text-fg";
  const externalProps = external ? { target: "_blank", rel: "noreferrer" } : {};
  return (
    <Link
      href={href}
      className={`${base} ${size} ${styles} ${className ?? ""}`}
      {...externalProps}
    >
      {children}
      {icon && (
        <span
          className={`flex items-center justify-center rounded-full transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-0.5 group-hover:scale-105 ${iconWrap} ${compact ? "h-7 w-7" : "h-8 w-8"}`}
        >
          <Icon name={icon} size={compact ? 14 : 16} />
        </span>
      )}
    </Link>
  );
}
