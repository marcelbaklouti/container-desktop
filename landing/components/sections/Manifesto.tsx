"use client";

import { useRef } from "react";
import { manifesto } from "@/lib/content";
import { gsap, useGSAP } from "@/components/gsap/core";

export function Manifesto() {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      const words = element.querySelectorAll(".manifesto-word");
      const media = gsap.matchMedia();
      media.add("(prefers-reduced-motion: no-preference)", () => {
        gsap.fromTo(
          words,
          { opacity: 0.12 },
          {
            opacity: 1,
            ease: "none",
            stagger: 0.06,
            scrollTrigger: {
              trigger: element,
              start: "top 75%",
              end: "center 42%",
              scrub: 0.4,
            },
          }
        );
      });
    },
    { scope: ref }
  );

  return (
    <section className="border-t border-border bg-bg-soft/30">
      <div ref={ref} className="mx-auto max-w-5xl px-5 py-32 sm:py-44">
        <p className="text-balance text-3xl font-semibold leading-snug tracking-tight sm:text-5xl sm:leading-snug">
          {manifesto.split(" ").map((word, i) => (
            <span key={i} className="manifesto-word inline">
              {word}{" "}
            </span>
          ))}
        </p>
      </div>
    </section>
  );
}
