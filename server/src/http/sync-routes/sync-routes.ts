import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { noticeRecordSchema } from "../../notice/http/notice-record-schema";
import { recordKindNameSchema } from "./record-kind-name-schema";
import { createSyncClientStateSchema } from "./create-sync-client-state-schema";
import { syncWriteCurrentSchema } from "./sync-write-current-schema";
import { syncWriteSchema } from "./sync-write-schema";
import { toSyncChangeResponse } from "./to-sync-change-response";
import { toSyncClientState } from "./to-sync-client-state";
import { toSyncWriteCurrent } from "./to-sync-write-current";
import { toSyncWrite } from "./to-sync-write";
import { weightTrendRecordSchema } from "../../weight-trend/http/weight-trend-record-schema";

const maximumWritesPerRequest = 500;
// coerce は入力の型が不明になり、OpenAPI の文書ではクエリが省略できることになってしまうので、必須と書く
const queryCount = z.coerce
  .number()
  .int()
  .nonnegative()
  .openapi({ param: { required: true } });

const routes = new OpenAPIHono<{ Bindings: Env }>()
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/sync/writes",
      operationId: "pushSyncWrites",
      summary: "端末の送り待ちをまとめて送る",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: z.object({
                clientState: createSyncClientStateSchema(z.number().int().nonnegative()),
                writes: z.array(syncWriteSchema).max(maximumWritesPerRequest),
                isFinalBatch: z.boolean(),
              }),
            },
          },
        },
      },
      responses: {
        200: {
          description: "書き込みごとの結果。要求の書き込みと同じ順",
          content: {
            "application/json": {
              schema: z.object({
                results: z.array(
                  z
                    .object({
                      writeId: z.string(),
                      result: z.string().openapi({
                        description:
                          "値が増えても古い版のアプリが読めるよう文字列で持つ。知らない値は端末が知らない結果として扱う",
                        example: "applied",
                      }),
                      rejectionReason: z.string().optional().openapi({
                        description:
                          "result が rejected のときだけ付く。値が増えても読めるよう文字列で持つ",
                      }),
                      current: syncWriteCurrentSchema.optional().openapi({
                        description:
                          "result が rejected のときだけ付く。その記録のサーバーの今の値で、要求の書き込みを全部当て終えた時点のもの。同じ書き込みの ID が再び届いたときも、最初の結果に、当て終えた時点の値を添える",
                      }),
                    })
                    .openapi("SyncWriteResult"),
                ),
              }),
            },
          },
        },
        400: { description: "要求の形が違うか、書き込みが 500 件を超えている。何も当てていない" },
        401: { description: "セッションが無いか、切れている" },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const { clientState, writes, isFinalBatch } = c.req.valid("json");
      const results = await getAccountDurableObject(c.env, c.var.accountId).pushSyncWrites(
        c.var.accountId,
        {
          clientState: toSyncClientState(clientState),
          writes: writes.map(toSyncWrite),
          isFinalBatch,
        },
      );
      return c.json(
        {
          results: results.map(({ writeId, outcome, rejectedRecord }) => ({
            writeId,
            result: outcome.result,
            rejectionReason: outcome.result === "rejected" ? outcome.reason : undefined,
            current: rejectedRecord === undefined ? undefined : toSyncWriteCurrent(rejectedRecord),
          })),
        },
        200,
      );
    },
  )
  .openapi(
    createRoute({
      method: "get",
      path: "/v1/sync/changes",
      operationId: "pullSyncChanges",
      summary: "前回の続きからの変更を取りに行く",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      request: {
        query: createSyncClientStateSchema(queryCount).extend({
          afterSequence: queryCount,
        }),
      },
      responses: {
        200: {
          description: "変更を、記録ごとにまとめて古い順に最大 500 件",
          content: {
            "application/json": {
              schema: z.object({
                changes: z.array(
                  z
                    .object({
                      sequence: z.number().int(),
                      kind: z.string().openapi({
                        description:
                          "知らない種類は読み飛ばす。種類が増えても古い版のアプリの同期が止まらないよう、文字列で持つ",
                        example: "weight_record",
                      }),
                      recordId: z.string(),
                      record: z.record(z.string(), z.unknown()),
                    })
                    .openapi("SyncChange"),
                ),
                hasMore: z.boolean(),
                nextAfterSequence: z.number().int(),
                startedOn: z.string().nullable().openapi({
                  description:
                    "YYYY-MM-DD。まだ決まっていないとき null。記録の通し番号によらず毎回載る",
                }),
              }),
            },
          },
        },
        400: { description: "要求の形が違う" },
        401: { description: "セッションが無いか、切れている" },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const { afterSequence, ...clientState } = c.req.valid("query");
      const pulled = await getAccountDurableObject(c.env, c.var.accountId).pullSyncChanges(
        c.var.accountId,
        { clientState: toSyncClientState(clientState), afterSequence },
      );
      return c.json(
        {
          changes: pulled.changes.map(toSyncChangeResponse),
          hasMore: pulled.hasMore,
          nextAfterSequence: pulled.nextAfterSequence,
          startedOn: pulled.startedOn ?? null,
        },
        200,
      );
    },
  );

// 応答のスキーマからは指さない。端末が、自分の登録簿と突き合わせるために読む
routes.openAPIRegistry.register("RecordKindName", recordKindNameSchema);
// 取りに行く変更の record は種類によらない形なので、種類ごとの値の形を部品として書き出す
routes.openAPIRegistry.register("NoticeRecord", noticeRecordSchema);
routes.openAPIRegistry.register("WeightTrendRecord", weightTrendRecordSchema);

export const syncRoutes = routes;
