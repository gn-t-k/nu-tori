import type Anthropic from "@anthropic-ai/sdk";
import {
  APIConnectionError,
  APIConnectionTimeoutError,
  APIError,
  APIUserAbortError,
  BadRequestError,
} from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { TokenUsage } from "../../../estimation/domain/estimation-provider";
import type { ConversationProvider, GeneratedReply } from "../../domain/conversation-provider";
import { ConversationProviderBadRequestError } from "../../domain/conversation-provider-bad-request-error";
import { ConversationProviderError } from "../../domain/conversation-provider-error";
import { ConversationProviderInvalidResponseError } from "../../domain/conversation-provider-invalid-response-error";
import { ConversationProviderTimedOutError } from "../../domain/conversation-provider-timed-out-error";
import { createSonnetReplyRequest } from "./create-sonnet-reply-request";
import { readStreamedReplyBody } from "./read-streamed-reply-body";
import { sonnetReplyOutputSchema } from "./sonnet-reply-output-schema";

// Claude Sonnet 5.5 に、流す形で返事を作らせる（#419 の「返事を作る」）。流れてきた JSON から本文のできた分を読み、onText に渡す。
// 時間の上限は試み全体の signal だけにする（1回の試みで呼ぶのは1回）。応答の中身（返事の本文を除く）は残さない
export const generateReplyWithSonnet = async (
  client: Anthropic,
  userId: string,
  { context, onText }: Parameters<ConversationProvider["generateReply"]>[0],
  signal: AbortSignal,
): R.ResultAsync<GeneratedReply, R.InferFailure<ConversationProvider["generateReply"]>> =>
  client.messages
    .create({ ...createSonnetReplyRequest(context), metadata: { user_id: userId } }, { signal })
    .then(async (stream) => {
      const streamed = await readStream(stream, onText);
      // 流している途中で signal が切れると、SDK は失敗にせず流れを終える
      if (signal.aborted) {
        return R.fail(new ConversationProviderTimedOutError());
      }
      return readReply(streamed, onText);
    })
    .then(
      (result) => result,
      (error: unknown) => {
        const failure = toProviderFailure(error);
        if (failure === undefined) {
          throw error;
        }
        return R.fail(failure);
      },
    );

type StreamedMessage = {
  text: string;
  // 本文のうち、onText に渡し終えた分
  passedBody: string;
  // 終わりの出来事が届かなければ null
  stopReason: Anthropic.StopReason | null;
  usage: TokenUsage;
};

const readStream = async (
  stream: AsyncIterable<Anthropic.RawMessageStreamEvent>,
  onText: (text: string) => void,
): Promise<StreamedMessage> => {
  const streamed: StreamedMessage = {
    text: "",
    passedBody: "",
    stopReason: null,
    usage: { inputTokens: 0, outputTokens: 0 },
  };
  for await (const event of stream) {
    if (event.type === "message_start") {
      streamed.usage.inputTokens = event.message.usage.input_tokens;
    }
    if (event.type === "message_delta") {
      streamed.stopReason = event.delta.stop_reason;
      streamed.usage.outputTokens = event.usage.output_tokens;
    }
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      streamed.text += event.delta.text;
      const body = readStreamedReplyBody(streamed.text);
      if (body !== undefined && body.length > streamed.passedBody.length) {
        onText(body.slice(streamed.passedBody.length));
        streamed.passedBody = body;
      }
    }
  }
  return streamed;
};

// 出力の上限で切れた応答と、答えなかった応答は、構造化出力が途中で終わっていたり空だったりする。
// 流しながら読めなかった本文の残り（JSON が body から始まらなかったときは本文のすべて）は、読み終えてから渡す
const readReply = (
  { text, passedBody, stopReason, usage }: StreamedMessage,
  onText: (text: string) => void,
): R.Result<
  GeneratedReply,
  ConversationProviderError | ConversationProviderInvalidResponseError
> => {
  if (stopReason === null) {
    return R.fail(new ConversationProviderError({ errorType: "stream_ended" }));
  }
  if (stopReason !== "end_turn") {
    return R.fail(new ConversationProviderInvalidResponseError({ usage }));
  }
  const parsed = sonnetReplyOutputSchema.safeParse(parseJson(text));
  if (!parsed.success) {
    return R.fail(new ConversationProviderInvalidResponseError({ usage }));
  }
  const rest = parsed.data.body.slice(passedBody.length);
  if (rest.length > 0) {
    onText(rest);
  }
  return R.succeed({ body: parsed.data.body, mealIds: parsed.data.mealIds, usage });
};

// JSON として読めないテキストは、形の確かめで落ちるよう undefined にする
const parseJson = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
};

// SDK が投げる提供元の失敗。SDK の失敗でないもの（想定外）は undefined を返し、呼び出し側が投げ直す。
// errorType は提供元のエラーの種類（応答に無ければ HTTP の状態コード、つなげなかったときは connection_error）。
// 流している途中のエラーの出来事は、状態コードの無い APIError で届く
const toProviderFailure = (
  error: unknown,
):
  | ConversationProviderError
  | ConversationProviderBadRequestError
  | ConversationProviderTimedOutError
  | undefined => {
  if (error instanceof APIConnectionTimeoutError || error instanceof APIUserAbortError) {
    return new ConversationProviderTimedOutError({ cause: error });
  }
  // 400 は状態コードで見分ける（月の支出の上限に当たったときも 400。メッセージの文字列では見分けない）
  if (error instanceof BadRequestError) {
    return new ConversationProviderBadRequestError({
      errorType: error.type ?? "http_400",
      cause: error,
    });
  }
  if (error instanceof APIConnectionError) {
    return new ConversationProviderError({ errorType: "connection_error", cause: error });
  }
  if (error instanceof APIError) {
    return new ConversationProviderError({
      errorType: error.type ?? `http_${error.status}`,
      cause: error,
    });
  }
  return undefined;
};
