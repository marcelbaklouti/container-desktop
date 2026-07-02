import Link from "next/link";
import Image from "next/image";
import { nav, site } from "@/lib/content";
import { Button } from "./Button";
import { Icon } from "./Icon";

export function Nav() {
  return (
    <header className="fixed inset-x-0 top-4 z-50 flex justify-center px-4">
      <div className="glass flex h-14 w-full max-w-3xl items-center justify-between rounded-full pl-5 pr-2 shadow-[0_12px_48px_rgba(0,0,0,0.4)]">
        <Link
          href="#top"
          className="flex items-center gap-2.5 text-sm font-semibold tracking-tight"
        >
          <Image src="/logo.png" alt="" width={26} height={26} priority />
          <span>{site.name}</span>
        </Link>

        <nav className="hidden items-center gap-6 text-sm text-fg-muted sm:flex">
          {nav.links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="transition-colors duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] hover:text-fg"
            >
              {l.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-1.5">
          <a
            href={site.repo}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub repository"
            className="hidden p-2 text-fg-muted transition-colors duration-300 hover:text-fg sm:inline-flex"
          >
            <Icon name="github" size={19} />
          </a>
          <Button href={site.releases} icon="download" external compact>
            Download
          </Button>
        </div>
      </div>
    </header>
  );
}
