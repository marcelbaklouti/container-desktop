import { site, faq } from "@/lib/content";

export function StructuredData() {
  const application = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: site.name,
    operatingSystem: "macOS 26 or later, Apple Silicon",
    applicationCategory: "DeveloperApplication",
    description: site.description,
    url: site.url,
    downloadUrl: site.releases,
    softwareVersion: site.version,
    license: "https://www.apache.org/licenses/LICENSE-2.0",
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
  };

  const faqPage = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faq.items.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
  };

  const webSite = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: site.name,
    url: site.url,
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(application) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqPage) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(webSite) }}
      />
    </>
  );
}
