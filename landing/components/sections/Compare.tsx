import { compare } from "@/lib/content";
import { Reveal } from "@/components/Reveal";

function Cell({ value }: { value: boolean | null }) {
  if (value === null) {
    return <span className="text-fg-faint" aria-label="Not applicable">·</span>;
  }
  return value ? (
    <span className="text-accent-soft" aria-label="Yes">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" className="inline">
        <path d="M20 6 9 17l-5-5" />
      </svg>
    </span>
  ) : (
    <span className="text-fg-faint" aria-label="No">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="inline">
        <path d="M18 6 6 18M6 6l12 12" />
      </svg>
    </span>
  );
}

export function Compare() {
  return (
    <section id="compare" className="border-t border-border bg-bg-soft/40">
      <div className="mx-auto max-w-5xl px-5 py-16 sm:py-24">
        <Reveal>
          <p className="text-sm font-medium uppercase tracking-widest text-accent-soft">
            Compare
          </p>
          <h2 className="mt-2 text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
            {compare.title}
          </h2>
          <p className="mt-3 max-w-2xl text-lg text-fg-muted">{compare.subtitle}</p>
        </Reveal>

        <Reveal delay={0.1}>
          <div className="glass mt-10 overflow-hidden rounded-2xl">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="px-4 py-3.5 font-medium text-fg-muted sm:px-6">
                    <span className="sr-only">Capability</span>
                  </th>
                  {compare.columns.map((column, i) => (
                    <th
                      scope="col"
                      key={column}
                      className={`px-3 py-3.5 text-center font-medium ${
                        i === compare.columns.length - 1 ? "text-accent-soft" : "text-fg-muted"
                      }`}
                    >
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {compare.rows.map((row, i) => (
                  <tr
                    key={row.label}
                    className={i < compare.rows.length - 1 ? "border-b border-border/60" : ""}
                  >
                    <th scope="row" className="px-4 py-3.5 text-left font-normal text-fg sm:px-6">
                      {row.label}
                    </th>
                    <td className="px-3 py-3.5 text-center">
                      <Cell value={row.cli} />
                    </td>
                    <td className="px-3 py-3.5 text-center">
                      <Cell value={row.dockerDesktop} />
                    </td>
                    <td className="bg-accent/[0.06] px-3 py-3.5 text-center">
                      <Cell value={row.containerDesktop} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-4 text-sm text-fg-faint">{compare.footnote}</p>
        </Reveal>
      </div>
    </section>
  );
}
