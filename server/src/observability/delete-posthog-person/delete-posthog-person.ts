import { ErrorFactory } from "@praha/error-factory";
import { z } from "zod";

// 出来事は非同期で消え、要求より前に取り込んだものだけが消える。人がいなくても 202 を返す
export const deletePostHogPerson = async (
  posthog: { projectId: string; personalApiKey: string },
  distinctId: string,
): Promise<void> => {
  const response = await fetch(
    `https://eu.posthog.com/api/projects/${posthog.projectId}/persons/bulk_delete/`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${posthog.personalApiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ distinct_ids: [distinctId], delete_events: true }),
    },
  );
  if (!response.ok) {
    throw new DeletePostHogPersonError({ reason: `${response.status}` });
  }
  const { deletion_errors: deletionErrors } = z
    .object({ deletion_errors: z.array(z.object({ step: z.string() })) })
    .parse(await response.json());
  if (deletionErrors.length > 0) {
    throw new DeletePostHogPersonError({
      reason: deletionErrors.map(({ step }) => step).join(", "),
    });
  }
};

export class DeletePostHogPersonError extends ErrorFactory({
  name: "DeletePostHogPersonError",
  message: ({ reason }) => `PostHog の人と出来事を消せなかった: ${reason}`,
  fields: ErrorFactory.fields<{ reason: string }>(),
}) {}
