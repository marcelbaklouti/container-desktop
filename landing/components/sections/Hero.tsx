import { hero, site } from "@/lib/content";
import { Button } from "@/components/Button";
import { Reveal } from "@/components/Reveal";
import { HeroGlow } from "@/components/HeroGlow";
import { ScreenshotFrame } from "@/components/ScreenshotFrame";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden px-5 pt-20 pb-16 sm:pt-28">
      <HeroGlow />
      <div className="mx-auto max-w-4xl text-center">
        <Reveal>
          <span className="glass inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-xs font-medium text-fg-muted">
            {hero.badge}
          </span>
        </Reveal>
        <Reveal delay={0.06}>
          <h1 className="mt-6 text-balance text-5xl font-semibold leading-[1.05] tracking-tight sm:text-6xl">
            {hero.title}
          </h1>
        </Reveal>
        <Reveal delay={0.12}>
          <p className="mx-auto mt-5 max-w-2xl text-pretty text-lg leading-relaxed text-fg-muted">
            {hero.subtitle}
          </p>
        </Reveal>
        <Reveal delay={0.18}>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <Button href={site.releases} icon="download" external>
              Download for macOS
            </Button>
            <Button href={site.repo} variant="secondary" icon="github" external>
              View on GitHub
            </Button>
          </div>
          <p className="mt-4 text-xs text-fg-faint">
            {site.requirements} · Free &amp; open source
          </p>
        </Reveal>
      </div>

      <Reveal delay={0.1} className="mx-auto mt-16 max-w-5xl">
        <ScreenshotFrame
          label={hero.screenshot.label}
          alt="Container Desktop main window"
          src={hero.screenshot.src}
          width={hero.screenshot.width}
          height={hero.screenshot.height}
          priority
        />
      </Reveal>
    </section>
  );
}
