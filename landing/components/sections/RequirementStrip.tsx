import { proofPoints } from "@/lib/content";
import { Icon } from "@/components/Icon";

export function RequirementStrip() {
  return (
    <section className="border-y border-border/70 bg-bg-soft/50">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-x-8 gap-y-3 px-5 py-5 text-sm text-fg-muted">
        {proofPoints.map((point) => (
          <span key={point} className="inline-flex items-center gap-2">
            <Icon name="check" size={15} className="text-accent-soft" />
            {point}
          </span>
        ))}
      </div>
    </section>
  );
}
