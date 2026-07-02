import { Hero } from "@/components/sections/Hero";
import { RequirementStrip } from "@/components/sections/RequirementStrip";
import { Highlights } from "@/components/sections/Highlights";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { FeatureRow } from "@/components/sections/FeatureRow";
import { FeatureStack } from "@/components/sections/FeatureStack";
import { Manifesto } from "@/components/sections/Manifesto";
import { BentoGrid } from "@/components/sections/BentoGrid";
import { Compare } from "@/components/sections/Compare";
import { WhatYouCanDo } from "@/components/sections/WhatYouCanDo";
import { FAQ } from "@/components/sections/FAQ";
import { Download } from "@/components/sections/Download";
import { StructuredData } from "@/components/StructuredData";
import { Marquee } from "@/components/Marquee";
import { features } from "@/lib/content";

export default function Home() {
  const splitFeatures = features.slice(0, 2);
  const stackedFeatures = features.slice(2);
  return (
    <>
      <StructuredData />
      <Hero />
      <RequirementStrip />
      <Marquee />
      <Highlights />
      <HowItWorks />
      {splitFeatures.map((feature, i) => (
        <FeatureRow key={feature.id} feature={feature} index={i} />
      ))}
      <Manifesto />
      <FeatureStack features={stackedFeatures} />
      <BentoGrid />
      <Compare />
      <WhatYouCanDo />
      <FAQ />
      <Download />
    </>
  );
}
