import { createFoodCompositionSearch } from "./create-food-composition-search";
import { loadFoodCompositionTable } from "./food-composition-table";

let foodComposition: ReturnType<typeof createFoodCompositionSearch> | undefined;

// 同梱の成分表を引く口。候補探し（findCandidates）と、食品番号からの引き当て（findByFoodNumber）
// 読み込みと索引づくりに 100 ms ほどかかるので、最初に呼ばれたときに1度だけ行い、Worker の起動では払わない
export const loadFoodComposition = () => {
  foodComposition ??= createFoodCompositionSearch(loadFoodCompositionTable());
  return foodComposition;
};
