"use client";

import { useRef } from "react";
import type { FeatureSection } from "@/lib/content";
import { Icon } from "@/components/Icon";
import { ScreenshotFrame } from "@/components/ScreenshotFrame";
import { gsap, useGSAP } from "@/components/gsap/core";

export function FeatureStack({ features }: { features: FeatureSection[] }) {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        const cards = gsap.utils.toArray<HTMLElement>(".stack-card", element);
        cards.forEach((card, i) => {
          if (i === cards.length - 1) return;
          gsap.to(card.querySelector(".stack-panel"), {
            scale: 0.93,
            opacity: 0.45,
            ease: "none",
            scrollTrigger: {
              trigger: cards[i + 1],
              start: "top bottom",
              end: "top top",
              scrub: true,
            },
          });
        });
      });
    },
    { scope: ref }
  );

  return (
    <div ref={ref} className="relative border-t border-border">
      {features.map((feature) => (
        <section
          key={feature.id}
          className="stack-card sticky top-0 flex min-h-[100dvh] items-center px-5 py-16"
        >
          <div className="stack-panel bezel mx-auto w-full max-w-6xl will-change-transform">
            <div className="bezel-core grid items-center gap-10 p-8 sm:p-12 lg:grid-cols-2 lg:gap-14">
              <div>
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
              </div>
              <ScreenshotFrame
                label={feature.screenshot.label}
                alt={feature.title}
                src={feature.screenshot.src}
                width={feature.screenshot.width}
                height={feature.screenshot.height}
                sizes="(min-width: 1024px) 520px, 100vw"
              />
            </div>
          </div>
        </section>
      ))}
    </div>
  );
}
