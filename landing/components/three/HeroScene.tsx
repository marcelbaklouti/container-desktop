"use client";

import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "motion/react";

const HeroCanvas = dynamic(() => import("./HeroCanvas"), { ssr: false });

export function HeroScene() {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(true);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const idle = window.requestAnimationFrame(() => setReady(true));
    return () => window.cancelAnimationFrame(idle);
  }, []);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      ([entry]) => setVisible(entry.isIntersecting),
      { rootMargin: "120px" }
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  if (reduce) return null;

  return (
    <div
      ref={ref}
      aria-hidden
      className="hero-scene pointer-events-none absolute inset-0 -z-10"
    >
      {ready && <HeroCanvas active={visible} />}
    </div>
  );
}
