import { DurableObject } from "cloudflare:workers";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { durableObjectMigrations } from "./durable-object-migrations";

export class AccountDurableObject extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
  }

  // ここから下は、開発用の環境で確かめる経路（src/http/verification-routes.ts）のため。確かめ終えたら消す

  override async alarm(): Promise<void> {}

  streamServerSentEventsForVerification(): ReadableStream<Uint8Array> {
    const encoder = new TextEncoder();
    let sent = 0;
    return new ReadableStream<Uint8Array>({
      pull: async (controller) => {
        await new Promise((resolve) => setTimeout(resolve, 1000));
        sent += 1;
        controller.enqueue(encoder.encode(`data: ${sent} ${new Date().toISOString()}\n\n`));
        if (sent === 5) {
          controller.close();
        }
      },
    });
  }

  async writeForVerification() {
    this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS verification (written_at TEXT)");
    this.ctx.storage.sql.exec(
      "INSERT INTO verification (written_at) VALUES (?)",
      new Date().toISOString(),
    );
    await this.ctx.storage.setAlarm(Date.now() + 60 * 60 * 1000);
    return {
      bookmark: await this.ctx.storage.getCurrentBookmark(),
      ...(await this.readForVerification()),
    };
  }

  async deleteAllForVerification() {
    await this.ctx.storage.deleteAll();
    return this.readForVerification();
  }

  async restoreForVerification(bookmark: string): Promise<void> {
    await this.ctx.storage.onNextSessionRestoreBookmark(bookmark);
    this.ctx.abort("戻すために止める");
  }

  async readForVerification() {
    const tables = this.ctx.storage.sql
      .exec<{ name: string }>("SELECT name FROM sqlite_master WHERE type = 'table'")
      .toArray()
      .map(({ name }) => name);
    const rows = tables.includes("verification")
      ? this.ctx.storage.sql
          .exec<{ written_at: string }>("SELECT written_at FROM verification")
          .toArray()
      : [];
    return { tables, rows, alarm: await this.ctx.storage.getAlarm() };
  }

  async classifyForVerification(text: string) {
    const startedAt = Date.now();
    const result = await this.env.AI.run("typesafe/jev", {
      state: text,
      questions: {
        kind: {
          type: "choice",
          instructions: "この文章は、食べたものの記録か、それ以外の会話か",
          criteria: { meal: "食べた・飲んだものを伝えている", conversation: "それ以外" },
        },
      },
    });
    // 返り値の型が unknown を含み RPC で渡せる型にならないので、文字列にして返す
    return { result: JSON.stringify(result), milliseconds: Date.now() - startedAt };
  }
}
