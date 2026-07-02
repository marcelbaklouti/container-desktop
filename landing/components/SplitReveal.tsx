"use client";

import { useRef, type ElementType, type ReactNode, type Ref } from "react";
import { gsap, SplitText, useGSAP } from "@/components/gsap/core";

export function SplitReveal({
  as: Tag = "div",
  children,
  className,
  delay = 0,
  scroll = true,
}: {
  as?: ElementType;
  children: ReactNode;
  className?: string;
  delay?: number;
  scroll?: boolean;
}) {
  const ref = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        const split = SplitText.create(element, {
          type: "words,lines",
          linesClass: "split-line",
          autoSplit: true,
        });
        gsap.set(element, { visibility: "visible" });
        gsap.from(split.words, {
          yPercent: 110,
          opacity: 0,
          duration: 0.9,
          ease: "power4.out",
          stagger: 0.045,
          delay,
          scrollTrigger: scroll
            ? { trigger: element, start: "top 88%", once: true }
            : undefined,
        });
        return () => split.revert();
      });
      media.add("(prefers-reduced-motion: reduce)", () => {
        gsap.set(element, { visibility: "visible" });
      });
    },
    { scope: ref }
  );

  const Component = Tag as "div";
  return (
    <Component
      ref={ref as Ref<HTMLDivElement>}
      className={className}
      style={{ visibility: "hidden" }}
    >
      {children}
    </Component>
  );
}
