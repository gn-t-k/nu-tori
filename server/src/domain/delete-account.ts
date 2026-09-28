export const deleteAccount = async (
  accountId: string,
  steps: {
    revokeAppleAuthorization: (accountId: string) => Promise<void>;
    deleteRecords: (accountId: string) => Promise<void>;
    deleteAuthentication: (accountId: string) => Promise<void>;
  },
): Promise<void> => {
  await steps.revokeAppleAuthorization(accountId);
  await steps.deleteRecords(accountId);
  // 途中で失敗しても同じセッションでやり直せるよう、認証を最後に消す
  await steps.deleteAuthentication(accountId);
};
