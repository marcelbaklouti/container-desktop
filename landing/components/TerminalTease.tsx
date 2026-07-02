"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion, useInView } from "motion/react";
import { hero } from "@/lib/content";

export function TerminalTease() {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, amount: 0.6 });
  const command = hero.terminal.command;
  const [typed, setTyped] = useState(reduce ? command : "");
  const [done, setDone] = useState(Boolean(reduce));

  useEffect(() => {
    if (reduce || !inView) return;
    let index = 0;
    const interval = setInterval(() => {
      index += 1;
      setTyped(command.slice(0, index));
      if (index >= command.length) {
        clearInterval(interval);
        setTimeout(() => setDone(true), 350);
      }
    }, 22);
    return () => clearInterval(interval);
  }, [reduce, inView, command]);

  return (
    <div ref={ref} className="mx-auto mt-10 w-full max-w-xl">
      <div className="bezel text-left">
        <div className="bezel-core">
          <div className="flex items-center gap-1.5 border-b border-border px-4 py-2.5">
            <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" aria-hidden />
            <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" aria-hidden />
            <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" aria-hidden />
            <span className="ml-2 text-xs text-fg-faint">zsh</span>
          </div>
          <div className="px-4 py-3.5 font-mono text-[13px] leading-relaxed">
            <span className="text-accent-soft">$ </span>
            <span className="text-fg">{typed}</span>
            {!done && <span className="terminal-caret text-fg" aria-hidden>▍</span>}
          </div>
        </div>
      </div>
      <p
        className={`mt-3 text-center text-sm text-fg-muted transition-opacity duration-700 ${
          done ? "opacity-100" : "opacity-0"
        }`}
      >
        {hero.terminal.punchline}
      </p>
    </div>
  );
}
