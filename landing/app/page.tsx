import { Hero } from "@/components/sections/Hero";
import { RequirementStrip } from "@/components/sections/RequirementStrip";
import { Highlights } from "@/components/sections/Highlights";
import { FeatureRow } from "@/components/sections/FeatureRow";
import { BentoGrid } from "@/components/sections/BentoGrid";
import { WhatYouCanDo } from "@/components/sections/WhatYouCanDo";
import { Download } from "@/components/sections/Download";
import { features } from "@/lib/content";

export default function Home() {
  return (
    <>
      <Hero />
      <RequirementStrip />
      <Highlights />
      {features.map((feature, i) => (
        <FeatureRow key={feature.id} feature={feature} index={i} />
      ))}
      <BentoGrid />
      <WhatYouCanDo />
      <Download />
    </>
  );
}
