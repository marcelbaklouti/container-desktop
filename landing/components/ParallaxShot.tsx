"use client";

import { useRef, type ReactNode } from "react";
import { gsap, useGSAP } from "@/components/gsap/core";

export function ParallaxShot({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        gsap.from(element, {
          opacity: 0,
          y: 48,
          scale: 0.965,
          duration: 1,
          ease: "power3.out",
          scrollTrigger: { trigger: element, start: "top 85%", once: true },
        });
        gsap.fromTo(
          element,
          { yPercent: 4 },
          {
            yPercent: -4,
            ease: "none",
            scrollTrigger: {
              trigger: element,
              start: "top bottom",
              end: "bottom top",
              scrub: 0.6,
            },
          }
        );
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
