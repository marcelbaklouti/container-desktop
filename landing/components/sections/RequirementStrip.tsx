import { Icon } from "@/components/Icon";

const facts = [
  "Native SwiftUI — no Electron",
  "Matches the container CLI",
  "Apple Silicon · macOS 26+",
  "Free & open source",
];

export function RequirementStrip() {
  return (
    <section className="border-y border-border/70 bg-bg-soft/50">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-x-8 gap-y-3 px-5 py-5 text-sm text-fg-muted">
        {facts.map((f) => (
          <span key={f} className="inline-flex items-center gap-2">
            <Icon name="check" size={15} className="text-accent-soft" />
            {f}
          </span>
        ))}
      </div>
    </section>
  );
}
