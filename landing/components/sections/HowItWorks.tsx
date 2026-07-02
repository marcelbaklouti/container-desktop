import { howItWorks } from "@/lib/content";
import { Reveal } from "@/components/Reveal";

export function HowItWorks() {
  return (
    <section id="how-it-works" className="border-t border-border">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:py-24">
        <Reveal>
          <p className="text-sm font-medium uppercase tracking-widest text-accent-soft">
            How it works
          </p>
          <h2 className="mt-2 text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
            {howItWorks.title}
          </h2>
          <p className="mt-3 max-w-2xl text-lg text-fg-muted">{howItWorks.subtitle}</p>
        </Reveal>

        <ol className="relative mt-12 grid gap-6 sm:grid-cols-3">
          <div
            aria-hidden
            className="absolute left-[10%] right-[10%] top-9 hidden h-px sm:block"
            style={{
              background:
                "linear-gradient(90deg, transparent, rgba(10,132,255,0.45), rgba(10,132,255,0.45), transparent)",
            }}
          />
          {howItWorks.steps.map((step, i) => (
            <Reveal key={step.number} delay={i * 0.08}>
              <li className="glass relative h-full rounded-2xl p-6">
                <span className="relative z-10 inline-flex h-11 w-11 items-center justify-center rounded-full border border-accent/40 bg-bg font-mono text-sm font-semibold text-accent-soft shadow-[0_0_24px_rgba(10,132,255,0.25)]">
                  {step.number}
                </span>
                <h3 className="mt-4 text-lg font-semibold">{step.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-fg-muted">{step.body}</p>
              </li>
            </Reveal>
          ))}
        </ol>
      </div>
    </section>
  );
}
