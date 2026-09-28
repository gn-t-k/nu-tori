import { vi } from "vitest";

export const mockPostHogBulkDeleteEndpointOk = (
  overrides?: Partial<{ deletion_errors: { person_uuid: string; step: string }[] }>,
) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(
    Response.json(
      {
        persons_found: 1,
        persons_deleted: 0,
        persons_queued_for_deletion: 1,
        events_queued_for_deletion: true,
        recordings_queued_for_deletion: false,
        deletion_errors: [],
        ...overrides,
      },
      { status: 202 },
    ),
  );
};

export const mockPostHogBulkDeleteEndpointError = (status: number) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status }));
};
