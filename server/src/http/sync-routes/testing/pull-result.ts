export type PullResult = {
  changes: { sequence: number; kind: string; recordId: string; record: Record<string, unknown> }[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | null;
};
