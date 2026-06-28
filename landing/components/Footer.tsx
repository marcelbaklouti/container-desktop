import Image from "next/image";
import { site, legal } from "@/lib/content";

export function Footer() {
  return (
    <footer className="border-t border-border">
      <div className="mx-auto max-w-6xl px-5 py-14">
        <div className="flex flex-col gap-10 sm:flex-row sm:items-start sm:justify-between">
          <div className="max-w-sm">
            <div className="flex items-center gap-2.5 font-semibold tracking-tight">
              <Image src="/logo.png" alt="" width={28} height={28} />
              {site.name}
            </div>
            <p className="mt-3 text-sm text-fg-muted">{site.tagline}.</p>
          </div>

          <div className="flex gap-12 text-sm">
            <div className="flex flex-col gap-2.5">
              <p className="text-fg-faint">Project</p>
              <a href={site.repo} target="_blank" rel="noreferrer" className="text-fg-muted hover:text-fg">
                GitHub
              </a>
              <a href={site.releases} target="_blank" rel="noreferrer" className="text-fg-muted hover:text-fg">
                Download
              </a>
            </div>
            <div className="flex flex-col gap-2.5">
              <p className="text-fg-faint">Requirements</p>
              <p className="text-fg-muted">Apple Silicon</p>
              <p className="text-fg-muted">macOS 26 Tahoe+</p>
              <p className="text-fg-muted">Version {site.version}</p>
            </div>
          </div>
        </div>

        <div className="mt-12 border-t border-border pt-6 text-xs leading-relaxed text-fg-faint">
          <p>{legal.long}</p>
          <p className="mt-3">
            © {new Date().getFullYear()} Marcel Baklouti · Apache License 2.0
          </p>
        </div>
      </div>
    </footer>
  );
}
