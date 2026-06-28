import { highlights } from "@/lib/content";
import { Icon } from "@/components/Icon";
import { Reveal } from "@/components/Reveal";

export function Highlights() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-5 py-16 sm:py-24">
      <Reveal>
        <h2 className="text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
          A better way to run containers on the Mac.
        </h2>
        <p className="mt-3 max-w-2xl text-lg text-fg-muted">
          The everyday essentials, done natively — plus a few things a wrapper can&apos;t.
        </p>
      </Reveal>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {highlights.map((h, i) => (
          <Reveal key={h.title} delay={(i % 4) * 0.06} className="h-full">
            <div className="glass h-full rounded-2xl p-6 transition-transform duration-200 ease-apple hover:-translate-y-0.5">
              <div className="grid h-10 w-10 place-items-center rounded-xl bg-accent/12 text-accent-soft">
                <Icon name={h.icon} size={20} />
              </div>
              <h3 className="mt-4 font-semibold">{h.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-fg-muted">{h.body}</p>
            </div>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
