import Image from "next/image";
import { bento } from "@/lib/content";
import { Icon } from "@/components/Icon";
import { Reveal } from "@/components/Reveal";

export function BentoGrid() {
  return (
    <section className="border-t border-border bg-bg-soft/40">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:py-24">
        <Reveal>
          <h2 className="text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
            Everything else, in one place.
          </h2>
          <p className="mt-3 max-w-2xl text-lg text-fg-muted">
            Networks, volumes, registries, and the builder — each a first-class part of the app.
          </p>
        </Reveal>

        <div className="mt-10 grid gap-5 sm:grid-cols-2">
          {bento.map((card, i) => (
            <Reveal key={card.title} delay={(i % 2) * 0.06} className="h-full">
              <div className="glass h-full overflow-hidden rounded-2xl transition-transform duration-200 ease-apple hover:-translate-y-0.5">
                <div className="relative aspect-[16/10] border-b border-border bg-bg">
                  <Image
                    src={card.screenshot.src!}
                    alt={card.title}
                    fill
                    sizes="(max-width: 640px) 100vw, 520px"
                    className="object-cover object-top"
                  />
                </div>
                <div className="p-6">
                  <div className="flex items-center gap-2.5">
                    <span className="grid h-8 w-8 place-items-center rounded-lg bg-accent/12 text-accent-soft">
                      <Icon name={card.icon} size={17} />
                    </span>
                    <h3 className="text-lg font-semibold">{card.title}</h3>
                  </div>
                  <p className="mt-2 text-sm leading-relaxed text-fg-muted">{card.body}</p>
                </div>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
