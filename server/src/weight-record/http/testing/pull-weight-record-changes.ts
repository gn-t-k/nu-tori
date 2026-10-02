import {
  pullSyncChanges,
  type PullResult,
} from "../../../http/sync-routes/testing/pull-sync-changes";

// 体重記録の書き込みには体重の傾向の変更が付いてくるので、体重記録とその削除の印の変更だけを残す
export const pullWeightRecordChanges = async (
  sessionToken: string,
  query: Parameters<typeof pullSyncChanges>[1] = {},
): Promise<PullResult> => {
  const pulled = await (await pullSyncChanges(sessionToken, query)).json<PullResult>();
  return {
    ...pulled,
    changes: pulled.changes.filter(({ kind }) => kind.startsWith("weight_record")),
  };
};
