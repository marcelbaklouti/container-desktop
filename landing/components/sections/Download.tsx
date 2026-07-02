import { site, legal, download } from "@/lib/content";
import { Button } from "@/components/Button";
import { Reveal } from "@/components/Reveal";
import { SplitReveal } from "@/components/SplitReveal";

export function Download() {
  return (
    <section
      id="download"
      className="relative overflow-hidden border-t border-border px-5 py-24"
    >
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-0 -z-10 h-72 w-[720px] max-w-[120vw] -translate-x-1/2 rounded-full"
        style={{
          background:
            "radial-gradient(50% 50% at 50% 50%, rgba(10,132,255,0.16), transparent 70%)",
          filter: "blur(40px)",
        }}
      />
      <div className="mx-auto max-w-3xl text-center">
        <SplitReveal
          as="h2"
          className="text-balance text-4xl font-semibold tracking-tight sm:text-5xl"
        >
          {download.title}
        </SplitReveal>
        <Reveal delay={0.15}>
          <p className="mx-auto mt-4 max-w-xl text-lg text-fg-muted">
            {download.subtitle}
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <Button href={site.releases} icon="download" external>
              Download for macOS
            </Button>
            <Button href={site.repo} variant="secondary" icon="github" external>
              View on GitHub
            </Button>
          </div>
          <p className="mt-4 text-sm text-fg-faint">
            {site.requirements} · {download.note}
          </p>
          <p className="mt-2 text-xs text-fg-faint">{legal.short}</p>
        </Reveal>
      </div>
    </section>
  );
}
