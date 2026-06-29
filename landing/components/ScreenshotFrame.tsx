import Image from "next/image";

export function ScreenshotFrame({
  src,
  alt,
  label,
  width,
  height,
  priority,
  sizes,
  className,
}: {
  src?: string;
  alt: string;
  label: string;
  width: number;
  height: number;
  priority?: boolean;
  sizes?: string;
  className?: string;
}) {
  // The app screenshots are full macOS windows (their own chrome + rounded, transparent corners),
  // so we render them bare with a soft drop-shadow rather than adding a second window frame.
  if (!src) {
    return (
      <div
        className={`glass grid place-items-center rounded-2xl ${className ?? ""}`}
        style={{ aspectRatio: `${width} / ${height}` }}
      >
        <div className="text-center">
          <div className="mx-auto mb-3 h-9 w-9 rounded-xl border border-border bg-glass" />
          <p className="text-sm font-medium text-fg-muted">{label}</p>
          <p className="mt-1 text-xs text-fg-faint">Screenshot coming soon</p>
        </div>
      </div>
    );
  }

  return (
    <Image
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      quality={90}
      sizes={sizes ?? "100vw"}
      className={`h-auto w-full ${className ?? ""}`}
      style={{ filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.55))" }}
    />
  );
}
