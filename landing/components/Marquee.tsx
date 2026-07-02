import { capabilities } from "@/lib/content";

export function Marquee() {
  const items = capabilities.map((capability) => capability.title);
  return (
    <div
      className="marquee relative overflow-hidden border-b border-border/70 bg-bg-soft/30 py-3.5"
      aria-hidden
    >
      <div className="marquee-track flex w-max items-center gap-14">
        {[0, 1].map((copy) => (
          <ul key={copy} className="flex items-center gap-14 pr-14">
            {items.map((item) => (
              <li
                key={`${copy}-${item}`}
                className="whitespace-nowrap text-sm font-medium tracking-wide text-fg-faint"
              >
                {item}
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
