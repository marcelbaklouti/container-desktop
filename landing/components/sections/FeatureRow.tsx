import type { FeatureSection } from "@/lib/content";
import { Icon } from "@/components/Icon";
import { Reveal } from "@/components/Reveal";
import { ScreenshotFrame } from "@/components/ScreenshotFrame";

export function FeatureRow({
  feature,
  index,
}: {
  feature: FeatureSection;
  index: number;
}) {
  const flip = index % 2 === 1;
  return (
    <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-16 sm:py-24 lg:grid-cols-2 lg:gap-16">
      <Reveal className={flip ? "lg:order-2" : ""}>
        <div className="inline-flex items-center gap-2 rounded-lg bg-accent/10 px-2.5 py-1 text-xs font-medium text-accent-soft">
          <Icon name={feature.icon} size={15} />
          {feature.eyebrow}
        </div>
        <h2 className="mt-4 text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
          {feature.title}
        </h2>
        <p className="mt-4 text-lg leading-relaxed text-fg-muted">{feature.body}</p>
        <ul className="mt-6 space-y-2.5">
          {feature.bullets.map((b) => (
            <li key={b} className="flex items-start gap-2.5 text-fg-muted">
              <Icon name="check" size={18} className="mt-0.5 shrink-0 text-accent-soft" />
              <span>{b}</span>
            </li>
          ))}
        </ul>
      </Reveal>

      <Reveal delay={0.08} className={flip ? "lg:order-1" : ""}>
        <ScreenshotFrame
          label={feature.screenshot.label}
          alt={feature.title}
          src={feature.screenshot.src}
          width={feature.screenshot.width}
          height={feature.screenshot.height}
        />
      </Reveal>
    </div>
  );
}
