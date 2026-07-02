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
  if (!src) {
    return (
      <div className={`bezel ${className ?? ""}`}>
        <div
          className="bezel-core grid place-items-center"
          style={{ aspectRatio: `${width} / ${height}` }}
        >
          <div className="text-center">
            <div className="mx-auto mb-3 h-9 w-9 rounded-xl border border-border bg-glass" />
            <p className="text-sm font-medium text-fg-muted">{label}</p>
            <p className="mt-1 text-xs text-fg-faint">Screenshot coming soon</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`bezel ${className ?? ""}`}>
      <div className="bezel-core">
        <Image
          src={src}
          alt={alt}
          width={width}
          height={height}
          priority={priority}
          quality={90}
          sizes={sizes ?? "100vw"}
          className="h-auto w-full"
        />
      </div>
    </div>
  );
}
