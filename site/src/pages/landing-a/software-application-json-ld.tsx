import { JsonScript } from "./json-script";
import { subscriptionPrices } from "../../subscription-prices";

// 検索のための SoftwareApplication の構造化データ。見えている文（ページの名前と料金の節）と一致させ、評価（aggregateRating）は書かない（#649 の「検索と構造化データ」）。
// 料金は特定商取引法に基づく表記と同じ subscriptionPrices から読む
export const SoftwareApplicationJsonLd = () => (
  <JsonScript type="application/ld+json" value={softwareApplication} />
);

const subscriptionOffer = (name: string, priceYen: number, billingDuration: string) => ({
  "@type": "Offer",
  name,
  price: String(priceYen),
  priceCurrency: "JPY",
  priceSpecification: {
    "@type": "UnitPriceSpecification",
    price: String(priceYen),
    priceCurrency: "JPY",
    billingDuration,
  },
});

const softwareApplication = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "nu-tori",
  operatingSystem: "iOS",
  applicationCategory: "HealthApplication",
  offers: [
    subscriptionOffer("月額", subscriptionPrices.monthlyYen, "P1M"),
    subscriptionOffer("年額", subscriptionPrices.yearlyYen, "P1Y"),
  ],
};
