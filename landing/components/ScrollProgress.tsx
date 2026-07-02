"use client";

import { useRef } from "react";
import { gsap, useGSAP } from "@/components/gsap/core";

export function ScrollProgress() {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    const media = gsap.matchMedia();
    media.add("(prefers-reduced-motion: no-preference)", () => {
      gsap.to(ref.current, {
        scaleX: 1,
        ease: "none",
        scrollTrigger: {
          start: 0,
          end: "max",
          scrub: 0.3,
        },
      });
    });
  });

  return (
    <div
      ref={ref}
      aria-hidden
      className="fixed inset-x-0 top-0 z-[60] h-px origin-left scale-x-0"
      style={{
        background:
          "linear-gradient(90deg, rgba(10,132,255,0.2), rgba(10,132,255,0.9))",
      }}
    />
  );
}
