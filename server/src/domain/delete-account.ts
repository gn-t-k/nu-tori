import { ErrorFactory } from "@praha/error-factory";

// 記録と写真の控えは、Better Auth の行を消す前と後の2回消す。
// 後の1回は、前の段のあいだに入り込んだもの（別の端末の同期の要求、裏で送っていた写真）を拾う。
// 後の1回で失敗したら、認証がもう無くてやり直せないので、報告して残ることを受け入れる
export const deleteAccount = async (
  accountId: string,
  steps: {
    revokeAppleAuthorization: (accountId: string) => Promise<void>;
    deleteRecords: (accountId: string) => Promise<void>;
    deleteMealPhotoFiles: (accountId: string) => Promise<void>;
    deleteAnalyticsEvents: (accountId: string) => Promise<void>;
    deleteAuthentication: (accountId: string) => Promise<void>;
    reportRetryFailure: (error: AccountDeletionRetryFailedError) => void;
  },
): Promise<void> => {
  await steps.revokeAppleAuthorization(accountId);
  await steps.deleteRecords(accountId);
  // R2 は Durable Object の表を読まずに消せるので、Durable Object を消したあとでも消せる
  await steps.deleteMealPhotoFiles(accountId);
  // 分析の出来事は消す要求より前に届いた分だけが消えるので、記録とアラームを消して送り手を止めてから消す
  await steps.deleteAnalyticsEvents(accountId);
  // 途中で失敗しても同じセッションでやり直せるよう、認証を最後に消す
  await steps.deleteAuthentication(accountId);
  await retryOnce("delete_records", steps.reportRetryFailure, () => steps.deleteRecords(accountId));
  await retryOnce("delete_meal_photo_files", steps.reportRetryFailure, () =>
    steps.deleteMealPhotoFiles(accountId),
  );
};

// stage は失敗した段。Sentry の報告に載せる
export class AccountDeletionRetryFailedError extends ErrorFactory({
  name: "AccountDeletionRetryFailedError",
  message: "アカウントの削除の2回目の段に失敗した",
  fields: ErrorFactory.fields<{ stage: "delete_records" | "delete_meal_photo_files" }>(),
}) {}

const retryOnce = async (
  stage: AccountDeletionRetryFailedError["stage"],
  report: (error: AccountDeletionRetryFailedError) => void,
  step: () => Promise<void>,
): Promise<void> => {
  await step().catch((cause: unknown) => {
    report(new AccountDeletionRetryFailedError({ stage, cause }));
  });
};
