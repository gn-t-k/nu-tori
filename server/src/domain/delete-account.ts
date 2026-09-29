export const deleteAccount = async (
  accountId: string,
  steps: {
    revokeAppleAuthorization: (accountId: string) => Promise<void>;
    deleteRecords: (accountId: string) => Promise<void>;
    deleteAnalyticsEvents: (accountId: string) => Promise<void>;
    deleteAuthentication: (accountId: string) => Promise<void>;
  },
): Promise<void> => {
  await steps.revokeAppleAuthorization(accountId);
  await steps.deleteRecords(accountId);
  // 分析の出来事は消す要求より前に届いた分だけが消えるので、記録とアラームを消して送り手を止めてから消す
  await steps.deleteAnalyticsEvents(accountId);
  // 途中で失敗しても同じセッションでやり直せるよう、認証を最後に消す
  await steps.deleteAuthentication(accountId);
};
