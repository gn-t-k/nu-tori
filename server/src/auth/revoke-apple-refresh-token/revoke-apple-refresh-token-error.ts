export class RevokeAppleRefreshTokenError extends Error {
  constructor(status: number) {
    super(`Apple の refresh token の取り消しに失敗した: ${status}`);
    this.name = "RevokeAppleRefreshTokenError";
  }
}
