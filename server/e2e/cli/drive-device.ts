import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { ErrorFactory } from "@praha/error-factory";
import { match } from "ts-pattern";
import { z } from "zod";
import {
  type DeviceConnection,
  type DeviceSession,
  createDeviceClient,
  savedSessionSchema,
} from "../device-client";
import { createScenario, scenarioNames } from "../create-scenario";
import { generateRecordId } from "../../src/domain/record-id";
import { syncWriteSchema } from "../../src/http/sync-routes/sync-write-schema";

// 手元で確かめる道具（.agents/skills/verify-server の device.sh）が、端末の代わりに要求を送る CLI。
// scenario は、時の経過で起きる知らせを待たずにアプリで見るための場面のアカウントを作る（docs/agents/ios-mac.md の「時の経過で起きる知らせを確かめる」）。
// 回のフォルダ（start.sh が作る）の run.env から Worker の URL と秘密の値と端末の ID を読み、セッションを sessions/<名前>.json に残し、送った要求と応答を evidence/requests.log に足す
const usage = `使い方:
  drive-device.ts uuid
  drive-device.ts sign-in <回のフォルダ> <名前> [--as-of <ISO 8601>]
  drive-device.ts scenario <回のフォルダ> <名前> <${scenarioNames.join(" | ")}>
  drive-device.ts push <回のフォルダ> <名前> '<書き込みの JSON の配列>'
  drive-device.ts pull <回のフォルダ> <名前> [--after <sequence>]
  drive-device.ts call <回のフォルダ> <名前> <メソッド> <パス> [--e2e] [--as-of <ISO 8601>]
                       [--json <本文>] [--body-file <パス> --content-type <型>] [--out <パス>] [--timeout <秒>]`;

const main = async ([command, ...args]: string[]): Promise<number> =>
  match(command)
    .with("uuid", () => {
      console.log(generateRecordId());
      return Promise.resolve(0);
    })
    .with("sign-in", () => runSignIn(args))
    .with("scenario", () => runScenario(args))
    .with("push", () => runPush(args))
    .with("pull", () => runPull(args))
    .with("call", () => runCall(args))
    .otherwise(() => Promise.reject(new UsageError({ reason: "コマンドが無いか、読めない" })));

const runSignIn = async (args: string[]): Promise<number> => {
  const { values, positionals } = parseArgs({
    args,
    allowPositionals: true,
    options: { "as-of": { type: "string" } },
  });
  const [runDir, name] = requirePositionals(positionals, z.tuple([z.string(), z.string()]));
  const run = await openRun(runDir);
  const asOf = parseOption("--as-of", isoDateTimeSchema, values["as-of"]);
  const session = await run.client.signIn(asOf === undefined ? undefined : new Date(asOf));
  await mkdir(join(runDir, "sessions"), { recursive: true });
  await writeFile(sessionPath(runDir, name), JSON.stringify(savedSessionSchema.parse(session)));
  console.log(session.accountId);
  return 0;
};

// 時の経過で起きる知らせの場面のアカウントを作り、セッションを sessions/<名前>.json に残す。
// アプリのデバッグビルドに渡す起動の値（ios/NuTori/App/ScenarioAccountLaunch.swift）を、KEY=値 の行で出す
const runScenario = async (args: string[]): Promise<number> => {
  const [runDir, name, scenario] = requirePositionals(
    parseArgs({ args, allowPositionals: true }).positionals,
    z.tuple([z.string(), z.string(), z.enum(scenarioNames)]),
  );
  const run = await openRun(runDir);
  const session = await createScenario(run.client, scenario);
  await mkdir(join(runDir, "sessions"), { recursive: true });
  await writeFile(sessionPath(runDir, name), JSON.stringify(savedSessionSchema.parse(session)));
  console.log(
    [
      `SCENARIO_SERVER_URL=${run.baseUrl}`,
      `SCENARIO_SESSION_TOKEN=${session.sessionToken}`,
      `SCENARIO_ACCOUNT_ID=${session.accountId}`,
    ].join("\n"),
  );
  return 0;
};

// 送る前に、書き込みを受け口と同じスキーマで確かめる。書き込みの id は省けば足す。受け付けられない書き込みがあれば、device-client が投げて 1 で終わる
const runPush = async (args: string[]): Promise<number> => {
  const [runDir, name, json] = requirePositionals(
    parseArgs({ args, allowPositionals: true }).positionals,
    z.tuple([z.string(), z.string(), z.string()]),
  );
  const run = await openRun(runDir);
  const parseResults = z
    .array(z.looseObject({ id: z.string().optional() }))
    .parse(JSON.parse(json))
    .map((write) => syncWriteSchema.safeParse({ ...write, id: write.id ?? generateRecordId() }));
  const invalid = parseResults.flatMap((result, index) =>
    result.success
      ? []
      : [
          `書き込み ${index}: ${result.error.issues.map((issue) => `${issue.path.join(".")} ${issue.message}`).join("、")}`,
        ],
  );
  if (invalid.length > 0) {
    console.error(`受け口の形に合わないので送らなかった\n${invalid.join("\n")}`);
    return 2;
  }
  const writes = parseResults.flatMap((result) => (result.success ? [result.data] : []));
  const results = await (await run.resume(name)).pushAppliedWrites(writes);
  console.log(JSON.stringify(results));
  return 0;
};

const runPull = async (args: string[]): Promise<number> => {
  const { values, positionals } = parseArgs({
    args,
    allowPositionals: true,
    options: { after: { type: "string" } },
  });
  const [runDir, name] = requirePositionals(positionals, z.tuple([z.string(), z.string()]));
  const run = await openRun(runDir);
  const after = parseOption("--after", z.coerce.number().int().nonnegative(), values.after);
  const changes = await (await run.resume(name)).pullAllChanges(after ?? 0);
  console.log(JSON.stringify(changes));
  return 0;
};

// 1回呼び、本文を標準出力（--out ならそのファイル）に、状態コードを標準エラーに出す。--timeout で切ったときも、それまでに届いた分を出して残す（見守る要求のため）
const runCall = async (args: string[]): Promise<number> => {
  const { values, positionals } = parseArgs({
    args,
    allowPositionals: true,
    options: {
      e2e: { type: "boolean" },
      "as-of": { type: "string" },
      json: { type: "string" },
      "body-file": { type: "string" },
      "content-type": { type: "string" },
      out: { type: "string" },
      timeout: { type: "string" },
    },
  });
  const [runDir, name, method, path] = requirePositionals(
    positionals,
    z.tuple([z.string(), z.string(), z.string(), z.string()]),
  );
  const content = await readContent(values);
  const timeout = parseOption("--timeout", z.coerce.number().positive(), values.timeout);
  const asOf = parseOption("--as-of", isoDateTimeSchema, values["as-of"]);
  // 送る口では残さず、ここで残す。見守る要求は --timeout で切るまで本文が終わらず、送る口で読み切って残すと、切ったときに何も残らないため
  const run = await openRun(runDir, { logResponses: false });
  const signal = timeout === undefined ? undefined : AbortSignal.timeout(timeout * 1000);
  const response = await (
    await run.resume(name)
  ).call(method, path, {
    ...(content === undefined
      ? {}
      : { headers: { "content-type": content.contentType }, body: content.body }),
    ...(signal === undefined ? {} : { signal }),
    ...(values.e2e === true || asOf !== undefined
      ? { e2e: asOf === undefined ? {} : { requestedAt: new Date(asOf) } }
      : {}),
  });
  const { bytes, timedOut } = await readBody(response);
  await run.log(
    `${method} ${path} -> ${response.status}${timedOut ? "（--timeout で切った）" : ""}`,
    response,
    bytes,
  );
  if (values.out === undefined) {
    process.stdout.write(bytes);
  } else {
    await writeFile(values.out, bytes);
  }
  console.error(`状態コード ${response.status}${timedOut ? `。${values.timeout} 秒で切った` : ""}`);
  return !timedOut && response.ok ? 0 : 1;
};

// 本文の指定は、なし・--json・--body-file と --content-type の対のどれか1つにする
const readContent = async (values: {
  json?: string | undefined;
  "body-file"?: string | undefined;
  "content-type"?: string | undefined;
}): Promise<{ body: BodyInit; contentType: string } | undefined> => {
  const { json, "body-file": bodyFile, "content-type": contentType } = values;
  if (json !== undefined && bodyFile === undefined && contentType === undefined) {
    return { body: json, contentType: "application/json" };
  }
  if (json === undefined && bodyFile !== undefined && contentType !== undefined) {
    return { body: await readFile(bodyFile), contentType };
  }
  if (json === undefined && bodyFile === undefined && contentType === undefined) {
    return undefined;
  }
  throw new UsageError({
    reason: "本文は --json か、--body-file と --content-type の対のどちらか1つで渡す",
  });
};

// 本文を読み切る。中断されたら、それまでに届いた分を返す
const readBody = async (response: Response): Promise<{ bytes: Uint8Array; timedOut: boolean }> => {
  const chunks: Uint8Array[] = [];
  const reader = response.body?.getReader();
  if (reader === undefined) {
    return { bytes: new Uint8Array(), timedOut: false };
  }
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        return { bytes: Buffer.concat(chunks), timedOut: false };
      }
      chunks.push(value);
    }
  } catch (error) {
    if (error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError")) {
      return { bytes: Buffer.concat(chunks), timedOut: true };
    }
    throw error;
  }
};

// run.env を読み、端末のクライアントを組む。logResponses なら、送った要求と応答をすべて証拠に足す
const openRun = async (runDir: string, { logResponses } = { logResponses: true }) => {
  const env = runEnvSchema.parse(
    Object.fromEntries(
      (
        await readFile(join(runDir, "run.env"), "utf8").catch(() => {
          throw new Error(`${runDir} に run.env が無い（start.sh で立てた回のフォルダを渡す）`);
        })
      )
        .split("\n")
        .filter((line) => line.includes("="))
        .map((line) => [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)]),
    ),
  );
  const log = async (line: string, response: Response, bytes: Uint8Array) => {
    const contentType = response.headers.get("content-type") ?? "";
    // 写真のような本文は、中身でなく大きさだけを残す
    const shown =
      /json|text|event-stream/.test(contentType) || contentType === ""
        ? Buffer.from(bytes).toString("utf8").slice(0, 4000)
        : `（バイナリ ${bytes.length} バイト）`;
    await mkdir(join(runDir, "evidence"), { recursive: true });
    await appendFile(
      join(runDir, "evidence", "requests.log"),
      `### ${new Date().toISOString()} ${line}\n${shown}\n\n`,
    );
  };
  const connection: DeviceConnection = {
    baseUrl: env.BASE_URL,
    signInSecret: env.E2E_SIGN_IN_SECRET,
    deviceId: env.DEVICE_ID,
    send: async (url, init) => {
      const response = await fetch(url, init);
      if (logResponses) {
        await log(
          `${init.method ?? "GET"} ${url.slice(env.BASE_URL.length)} -> ${response.status}`,
          response,
          new Uint8Array(await response.clone().arrayBuffer()),
        );
      }
      return response;
    },
  };
  const client = createDeviceClient(connection);
  const resume = async (name: string): Promise<DeviceSession> =>
    client.resume(
      savedSessionSchema.parse(
        JSON.parse(
          await readFile(sessionPath(runDir, name), "utf8").catch(() => {
            throw new Error(`セッション ${name} が無い（sign-in ${runDir} ${name} で作る）`);
          }),
        ),
      ),
    );
  return { client, resume, log, baseUrl: env.BASE_URL };
};

const runEnvSchema = z.object({
  BASE_URL: z.string().min(1),
  E2E_SIGN_IN_SECRET: z.string().min(1),
  DEVICE_ID: z.string().min(1),
});

const sessionPath = (runDir: string, name: string) => join(runDir, "sessions", `${name}.json`);

const isoDateTimeSchema = z.iso.datetime({ offset: true });

// オプションの値を確かめて読む。渡されていなければ undefined
const parseOption = <T extends z.ZodType>(
  name: string,
  schema: T,
  value: string | undefined,
): z.infer<T> | undefined => {
  if (value === undefined) {
    return undefined;
  }
  const parsed = schema.safeParse(value);
  if (!parsed.success) {
    throw new UsageError({ reason: `${name} の値が読めない（${value}）` });
  }
  return parsed.data;
};

// 位置の引数を読む。1つ目（回のフォルダ）は絶対パスにする
const requirePositionals = <T extends z.ZodTuple>(positionals: string[], shape: T): z.infer<T> => {
  const parsed = shape.safeParse(
    positionals.map((value, index) => (index === 0 ? resolve(value) : value)),
  );
  if (!parsed.success) {
    throw new UsageError({ reason: "位置の引数の数か値が合わない" });
  }
  return parsed.data;
};

// 引数が読めないとき。使い方を添えて 2 で終わる
class UsageError extends ErrorFactory({
  name: "UsageError",
  message: ({ reason }) => reason,
  fields: ErrorFactory.fields<{ reason: string }>(),
}) {}

try {
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  if (error instanceof Error && error.name === "UsageError") {
    console.error(`${error.message}\n${usage}`);
    process.exitCode = 2;
  } else {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}
