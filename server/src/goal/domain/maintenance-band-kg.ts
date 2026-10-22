import paceJson from "../../../../shared/pace.json";

// 維持（期限後の維持を含む）で保つ、目標体重からの幅（±、端を含む）。ペースの判定と、1日の目安の必要な速さで同じ幅を使う。出荷後に調整する初期値。端末と両方に置く決めごとなので、正本は shared/ の JSON
export const maintenanceBandKg = paceJson.maintenanceBandKg;
