export class DeletePostHogPersonError extends Error {
  constructor(reason: string) {
    super(`PostHog の人と出来事を消せなかった: ${reason}`);
    this.name = "DeletePostHogPersonError";
  }
}
