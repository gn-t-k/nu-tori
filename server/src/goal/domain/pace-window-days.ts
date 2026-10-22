import paceJson from "../../../../shared/pace.json";

// ペースの判定で体重の傾向の動きを見る日数（判定する日を含む）。目標を立ててからこの日数たつまでは判定しない。端末と両方に置く決めごとなので、正本は shared/ の JSON
export const paceWindowDays = paceJson.windowDays;
