import { z } from "zod";

// Xcode と LocalTesting は App Store が署名しないので、鎖を確かめる入口を通らない。
// 届く値をそのまま型にし、受け付けるか（Production と Sandbox だけ）は使う側で決める
export const appStoreEnvironmentSchema = z.enum(["Production", "Sandbox", "Xcode", "LocalTesting"]);

export type AppStoreEnvironment = z.output<typeof appStoreEnvironmentSchema>;
