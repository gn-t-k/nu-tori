// 料理と材料の今の量の出どころ。推定したまま（estimated）か、使う人が直した（corrected）か。
// 料理の量に比例させた材料の量は、推定したままにする（#332 の「料理の量を直す」）
export type QuantitySource = "estimated" | "corrected";
