import { faq } from "@/lib/content";
import { Reveal } from "@/components/Reveal";

export function FAQ() {
  return (
    <section id="faq" className="border-t border-border">
      <div className="mx-auto max-w-3xl px-5 py-16 sm:py-24">
        <Reveal>
          <p className="text-center text-sm font-medium uppercase tracking-widest text-accent-soft">
            FAQ
          </p>
          <h2 className="mt-2 text-balance text-center text-3xl font-semibold tracking-tight sm:text-4xl">
            {faq.title}
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-center text-lg text-fg-muted">
            {faq.subtitle}
          </p>
        </Reveal>

        <div className="mt-10 space-y-3">
          {faq.items.map((item, i) => (
            <Reveal key={item.question} delay={Math.min(i * 0.04, 0.2)}>
              <details className="faq-item glass group rounded-xl">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 px-5 py-4 text-left font-medium [&::-webkit-details-marker]:hidden">
                  <span>{item.question}</span>
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden
                    className="shrink-0 text-fg-faint transition-transform duration-300 group-open:rotate-45"
                  >
                    <path d="M12 5v14M5 12h14" />
                  </svg>
                </summary>
                <p className="px-5 pb-5 text-sm leading-relaxed text-fg-muted">{item.answer}</p>
              </details>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
