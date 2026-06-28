import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export const alt = "Container Desktop — the Apple container GUI for your Mac";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function OpengraphImage() {
  const iconData = await readFile(join(process.cwd(), "public/logo.png"));
  const icon = `data:image/png;base64,${iconData.toString("base64")}`;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: "0 96px",
          background:
            "radial-gradient(900px 520px at 82% -12%, rgba(10,132,255,0.28), transparent 60%), #08090c",
          color: "#f2f2f4",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 48 }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={icon} width={216} height={216} alt="" />
          <div style={{ display: "flex", flexDirection: "column" }}>
            <div style={{ fontSize: 76, fontWeight: 700, letterSpacing: -2 }}>
              Container Desktop
            </div>
            <div style={{ fontSize: 36, color: "#a1a2ab", marginTop: 12 }}>
              The Apple container GUI for your Mac.
            </div>
          </div>
        </div>
        <div style={{ display: "flex", marginTop: 60, fontSize: 27, color: "#71727c" }}>
          Apple Silicon · macOS 26 Tahoe+ · Free &amp; open source
        </div>
      </div>
    ),
    { ...size },
  );
}
