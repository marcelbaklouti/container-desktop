import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Screenshots are text-heavy; allow a higher quality than the default 75.
    qualities: [75, 90],
  },
};

export default nextConfig;
