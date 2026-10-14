import { z } from "@hono/zod-openapi";
import { proposalPaces } from "../../goal/domain/proposal-pace";

// 案の速さと、大変さの段階。目標案と自分で決める目標体重の応答が使う
export const proposalPaceSchema = z
  .enum(proposalPaces)
  .openapi("ProposalPace", { description: "gentle・standard・hard" });
