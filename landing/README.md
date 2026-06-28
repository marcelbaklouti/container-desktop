# Container Desktop — landing page

Marketing site for **Container Desktop**, the native macOS app for Apple's `container` runtime.

Built with **Next.js 16** (App Router) · **React 19** · **Tailwind CSS v4** · **Motion** · **pnpm**. Dark, Apple-like, animated, accessible.

## Develop

```sh
pnpm install
pnpm dev          # http://localhost:3000
pnpm build        # production build (Turbopack)
pnpm lint         # ESLint (flat config)
```

## Editing content

All copy and data live in **`lib/content.ts`** — `site`, `hero`, `features`, `bento`, `capabilities`, and the legal notices. Sections are pure layout, so you rarely touch the components.

Icons are a custom inline-SVG set in **`components/Icon.tsx`** (no icon dependency, no "spark" glyphs).

## Screenshots

The per-area app screenshots live in **`public/screens/`** — `Container.png` (hero), `Images.png`, `Machines.png`, `System.png` (feature rows), and `Networks.png` / `Volumes.png` / `Registries.png` / `Builder.png` (the bento grid). They're wired up in **`lib/content.ts`**.

They're full macOS windows (their own chrome + transparent rounded corners), so `ScreenshotFrame` renders them bare with a soft drop-shadow — no second window frame. To refresh one, replace the PNG (keep the name); update its `width`/`height` in `content.ts` if the pixel size changes. Any `screenshot` with no `src` falls back to a labelled placeholder. `public/og.png` (1200×630) is still optional for the social card.

## Deploy (Vercel)

- Import the repo on Vercel and set **Root Directory = `landing`**.
- Before going live, set the real domain in **`lib/content.ts` → `site.url`** (used for `metadataBase`/OpenGraph) and add `public/og.png`.

## Legal

Container Desktop is an independent, open-source project and is **not affiliated with, endorsed by, or sponsored by Apple Inc.** Apple, macOS, and Apple Silicon are trademarks of Apple Inc.
