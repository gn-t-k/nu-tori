import { betterAuth } from "better-auth";
import { createAuthenticationOptions } from "./create-authentication-options";

export const createAuthentication = (env: Env, requestUrl: string) =>
  betterAuth(createAuthenticationOptions(env, requestUrl));
