"use client";

import { useRef, type ReactNode } from "react";
import { gsap, useGSAP } from "@/components/gsap/core";

export function StaggerGroup({
  children,
  className,
  selector = ":scope > *",
  y = 24,
}: {
  children: ReactNode;
  className?: string;
  selector?: string;
  y?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const targets = element.querySelectorAll(selector);
      if (targets.length === 0) return;
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        gsap.from(targets, {
          opacity: 0,
          y,
          duration: 0.7,
          ease: "power3.out",
          stagger: 0.08,
          scrollTrigger: { trigger: element, start: "top 85%", once: true },
        });
      });
    },
    { scope: ref }
  );

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}

export function GrowLine({ className, style }: { className?: string; style?: React.CSSProperties }) {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        gsap.fromTo(
          element,
          { scaleX: 0 },
          {
            scaleX: 1,
            ease: "none",
            scrollTrigger: {
              trigger: element,
              start: "top 90%",
              end: "top 45%",
              scrub: 0.5,
            },
          }
        );
      });
    },
    { scope: ref }
  );

  return <div ref={ref} aria-hidden className={`${className ?? ""} origin-left`} style={style} />;
}
