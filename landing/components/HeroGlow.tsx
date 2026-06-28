"use client";

import { motion, useReducedMotion } from "motion/react";

export function HeroGlow() {
  const reduce = useReducedMotion();
  return (
    <motion.div
      aria-hidden
      className="pointer-events-none absolute left-1/2 top-[-12%] -z-10 h-[520px] w-[860px] max-w-[130vw] -translate-x-1/2 rounded-full"
      style={{
        background:
          "radial-gradient(50% 50% at 50% 50%, rgba(10,132,255,0.22), rgba(10,132,255,0) 70%)",
        filter: "blur(44px)",
      }}
      animate={reduce ? undefined : { opacity: [0.5, 0.8, 0.5], y: [0, -16, 0] }}
      transition={{ duration: 9, repeat: Infinity, ease: "easeInOut" }}
    />
  );
}
