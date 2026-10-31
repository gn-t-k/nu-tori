import examples from "./landing-a-examples.json";

// 写真は Wikimedia Commons の CC0（Ocdp）で、nu-tori の利用者の食事ではない。下の examplePhotoMeals がトップレベルで読むので先に置く
const photos: Partial<Record<string, { src: string; alt: string }>> = {
  oyakodon: { src: "/landing-a/oyakodon.webp", alt: "親子丼の写真" },
  curry: { src: "/landing-a/curry.webp", alt: "カレーライスの写真" },
  onigiri: { src: "/landing-a/onigiri.webp", alt: "のりを巻いたおにぎり2つの写真" },
};

// 見本の食事。料理・材料・量・栄養は server/scripts/print-landing-a-examples.ts が成分表から出す（server/AGENTS.md の「出し方のページと LP の例」）
export const examplePhotoMeals = examples.photoMeals.map((meal) => {
  const photo = photos[meal.key];
  if (photo === undefined) {
    throw new Error(`見本の食事に写真が無い: ${meal.key}`);
  }
  return { ...meal, photo };
});

export type ExamplePhotoMeal = (typeof examplePhotoMeals)[number];
