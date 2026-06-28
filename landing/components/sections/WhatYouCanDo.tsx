import { capabilities } from "@/lib/content";
import { Icon } from "@/components/Icon";
import { Reveal } from "@/components/Reveal";

export function WhatYouCanDo() {
  return (
    <section id="capabilities" className="border-t border-border">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:py-24">
        <Reveal>
          <h2 className="text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
            What you can do
          </h2>
          <p className="mt-3 max-w-2xl text-lg text-fg-muted">
            The same guides that ship inside the app — a tour of everything Container Desktop manages.
          </p>
        </Reveal>

        <div className="mt-10 grid gap-x-10 gap-y-1 sm:grid-cols-2">
          {capabilities.map((c, i) => (
            <Reveal key={c.title} delay={(i % 2) * 0.05}>
              <div className="flex items-start gap-3 border-t border-border py-5">
                <Icon name={c.icon} size={18} className="mt-0.5 shrink-0 text-accent-soft" />
                <div>
                  <h3 className="font-medium">{c.title}</h3>
                  <p className="mt-1 text-sm text-fg-muted">{c.body}</p>
                </div>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
