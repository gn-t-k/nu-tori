import { ErrorFactory } from "@praha/error-factory";

export class AppStoreSignatureUnverifiedError extends ErrorFactory({
  name: "AppStoreSignatureUnverifiedError",
  message: "App Store の署名つきの値の署名を確かめられなかった",
}) {}
