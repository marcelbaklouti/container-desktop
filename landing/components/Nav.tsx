import Link from "next/link";
import { nav, site } from "@/lib/content";
import { Button } from "./Button";
import { Icon } from "./Icon";

export function Nav() {
  return (
    <header className="glass sticky top-0 z-50 border-x-0 border-t-0">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5">
        <Link
          href="#top"
          className="flex items-center gap-2.5 font-semibold tracking-tight"
        >
          <span className="grid h-7 w-7 place-items-center rounded-lg bg-accent/15 text-accent-soft">
            <Icon name="box" size={16} />
          </span>
          {site.name}
        </Link>

        <nav className="hidden items-center gap-7 text-sm text-fg-muted sm:flex">
          {nav.links.map((l) => (
            <a key={l.href} href={l.href} className="transition-colors hover:text-fg">
              {l.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <a
            href={site.repo}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub repository"
            className="hidden text-fg-muted transition-colors hover:text-fg sm:inline-flex"
          >
            <Icon name="github" size={20} />
          </a>
          <Button
            href={site.releases}
            icon="download"
            external
            className="px-4 py-2"
          >
            Download
          </Button>
        </div>
      </div>
    </header>
  );
}
