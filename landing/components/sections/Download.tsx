import { site, legal } from "@/lib/content";
import { Button } from "@/components/Button";
import { Reveal } from "@/components/Reveal";

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
        <Reveal>
          <h2 className="text-balance text-4xl font-semibold tracking-tight sm:text-5xl">
            Get Container Desktop
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-lg text-fg-muted">
            Download the latest release and manage Apple&apos;s container runtime from a native Mac app.
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
            {site.requirements} · The DMG is hosted on GitHub Releases.
          </p>
          <p className="mt-2 text-xs text-fg-faint">{legal.short}</p>
        </Reveal>
      </div>
    </section>
  );
}
