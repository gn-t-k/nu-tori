import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { catchAnthropicFailure } from "../../../durable-object/anthropic/catch-anthropic-failure";
import { parseJson } from "../../../durable-object/anthropic/parse-json";
import type { TokenUsage } from "../../../domain/token-usage";
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
export const generateReplyWithSonnet = (
  client: Anthropic,
  userId: string,
  { context, onText }: Parameters<ConversationProvider["generateReply"]>[0],
  signal: AbortSignal,
): R.ResultAsync<GeneratedReply, R.InferFailure<ConversationProvider["generateReply"]>> =>
  R.pipe(
    // 流している途中のエラーも提供元の失敗にするため、流れを読み終えるまでを1つの呼び出しとして包む
    catchAnthropicFailure(
      client.messages
        .create({ ...createSonnetReplyRequest(context), metadata: { user_id: userId } }, { signal })
        .then(async (stream) => readStream(stream, onText)),
      (failure) =>
        match(failure)
          .with(
            { type: "timed_out" },
            ({ cause }) => new ConversationProviderTimedOutError({ cause }),
          )
          .with(
            { type: "bad_request" },
            ({ errorType, cause }) => new ConversationProviderBadRequestError({ errorType, cause }),
          )
          .with(
            { type: "provider_error" },
            ({ errorType, cause }) => new ConversationProviderError({ errorType, cause }),
          )
          .exhaustive(),
    ),
    // 流している途中で signal が切れると、SDK は失敗にせず流れを終える
    R.andThen((streamed) =>
      signal.aborted
        ? R.fail(new ConversationProviderTimedOutError())
        : readReply(streamed, onText),
    ),
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
