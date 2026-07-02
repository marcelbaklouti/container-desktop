import { howItWorks } from "@/lib/content";
import { Reveal } from "@/components/Reveal";
import { SplitReveal } from "@/components/SplitReveal";
import { StaggerGroup, GrowLine } from "@/components/StaggerGroup";

export function HowItWorks() {
  return (
    <section id="how-it-works" className="border-t border-border">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:py-24">
        <Reveal>
          <p className="text-sm font-medium uppercase tracking-widest text-accent-soft">
            How it works
          </p>
        </Reveal>
        <SplitReveal
          as="h2"
          className="mt-2 text-balance text-3xl font-semibold tracking-tight sm:text-4xl"
        >
          {howItWorks.title}
        </SplitReveal>
        <Reveal delay={0.1}>
          <p className="mt-3 max-w-2xl text-lg text-fg-muted">{howItWorks.subtitle}</p>
        </Reveal>

        <div className="relative mt-12">
          <GrowLine
            className="absolute left-[10%] right-[10%] top-9 hidden h-px sm:block"
            style={{
              background:
                "linear-gradient(90deg, transparent, rgba(10,132,255,0.55), rgba(10,132,255,0.55), transparent)",
            }}
          />
          <StaggerGroup className="grid gap-6 sm:grid-cols-3" y={32}>
            {howItWorks.steps.map((step) => (
              <div key={step.number} className="glass relative h-full rounded-2xl p-6">
                <span className="relative z-10 inline-flex h-11 w-11 items-center justify-center rounded-full border border-accent/40 bg-bg font-mono text-sm font-semibold text-accent-soft shadow-[0_0_24px_rgba(10,132,255,0.25)]">
                  {step.number}
                </span>
                <h3 className="mt-4 text-lg font-semibold">{step.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-fg-muted">{step.body}</p>
              </div>
            ))}
          </StaggerGroup>
        </div>
      </div>
    </section>
  );
}
