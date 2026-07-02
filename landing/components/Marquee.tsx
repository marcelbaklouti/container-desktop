import { capabilities } from "@/lib/content";

export function Marquee() {
  const items = capabilities.map((capability) => capability.title);
  return (
    <div
      className="marquee relative overflow-hidden border-b border-border/70 bg-bg-soft/30 py-3.5"
      aria-hidden
    >
      <div className="marquee-track flex w-max items-center gap-10">
        {[0, 1].map((copy) => (
          <ul key={copy} className="flex items-center gap-10 pr-10">
            {items.map((item) => (
              <li
                key={`${copy}-${item}`}
                className="flex items-center gap-10 whitespace-nowrap text-sm font-medium tracking-wide text-fg-faint"
              >
                {item}
                <span className="h-1 w-1 rounded-full bg-accent/60" />
              </li>
            ))}
          </ul>
        ))}
      </div>
      <div className="pointer-events-none absolute inset-y-0 left-0 w-24 bg-gradient-to-r from-bg to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 w-24 bg-gradient-to-l from-bg to-transparent" />
    </div>
  );
}
