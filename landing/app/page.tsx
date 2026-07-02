import { Hero } from "@/components/sections/Hero";
import { RequirementStrip } from "@/components/sections/RequirementStrip";
import { Highlights } from "@/components/sections/Highlights";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { FeatureRow } from "@/components/sections/FeatureRow";
import { BentoGrid } from "@/components/sections/BentoGrid";
import { Compare } from "@/components/sections/Compare";
import { WhatYouCanDo } from "@/components/sections/WhatYouCanDo";
import { FAQ } from "@/components/sections/FAQ";
import { Download } from "@/components/sections/Download";
import { StructuredData } from "@/components/StructuredData";
import { features } from "@/lib/content";

export default function Home() {
  return (
    <>
      <StructuredData />
      <Hero />
      <RequirementStrip />
      <Highlights />
      <HowItWorks />
      {features.map((feature, i) => (
        <FeatureRow key={feature.id} feature={feature} index={i} />
      ))}
      <BentoGrid />
      <Compare />
      <WhatYouCanDo />
      <FAQ />
      <Download />
    </>
  );
}
