// 目標案の速さの段階。大変さの段階でもある
export const proposalPaces = ["gentle", "standard", "hard"] as const;

export type ProposalPace = (typeof proposalPaces)[number];
