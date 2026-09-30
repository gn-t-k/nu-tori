export type PushResults = {
  results: {
    writeId: string;
    result: string;
    rejectionReason?: string;
    current?: {
      status: string;
      change?: { kind: string; recordId: string; record: Record<string, unknown> };
    };
  }[];
};
