import { beforeEach, describe, expect, test } from "vitest";
import { mockPostHogBulkDeleteEndpointError, mockPostHogBulkDeleteEndpointOk } from "../testing";
import { DeletePostHogPersonError, deletePostHogPerson } from "./index";

describe("PostHog の人と出来事の削除", () => {
  describe("PostHog が受け付けたとき", () => {
    let posthog: { projectId: string; personalApiKey: string };
    let fetchSpy: ReturnType<typeof mockPostHogBulkDeleteEndpointOk>;
    beforeEach(() => {
      posthog = { projectId: "12345", personalApiKey: "phx_test" };
      fetchSpy = mockPostHogBulkDeleteEndpointOk();
    });

    test("distinct_id の人を出来事とあわせて消す要求を EU に送ること", async () => {
      await deletePostHogPerson(posthog, "account-1");
      const [url, init] = fetchSpy.mock.calls[0] ?? [];
      expect({
        url,
        authorization: new Headers(init?.headers).get("authorization"),
        body: await new Response(init?.body).json(),
      }).toEqual({
        url: "https://eu.posthog.com/api/projects/12345/persons/bulk_delete/",
        authorization: "Bearer phx_test",
        body: { distinct_ids: ["account-1"], delete_events: true },
      });
    });
  });

  describe("PostHog が一部を消せなかったと返したとき", () => {
    let posthog: { projectId: string; personalApiKey: string };
    beforeEach(() => {
      posthog = { projectId: "12345", personalApiKey: "phx_test" };
      mockPostHogBulkDeleteEndpointOk({
        deletion_errors: [{ person_uuid: "person-1", step: "delete_person" }],
      });
    });

    test("失敗を投げること", async () => {
      await expect(deletePostHogPerson(posthog, "account-1")).rejects.toThrow(
        DeletePostHogPersonError,
      );
    });
  });

  describe("PostHog が失敗を返したとき", () => {
    let posthog: { projectId: string; personalApiKey: string };
    beforeEach(() => {
      posthog = { projectId: "12345", personalApiKey: "phx_test" };
      mockPostHogBulkDeleteEndpointError(503);
    });

    test("失敗を投げること", async () => {
      await expect(deletePostHogPerson(posthog, "account-1")).rejects.toThrow(
        DeletePostHogPersonError,
      );
    });
  });
});
