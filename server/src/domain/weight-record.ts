export type WeightRecord = {
  id: string;
  weightKg: number;
  measuredAt: Date;
  timeZone: string;
  version: number;
  imported:
    | {
        sourceAppName: string;
        sourceBundleId: string;
        healthkitSampleUuid: string;
        bodyFat: { percentage: number; healthkitSampleUuid: string } | undefined;
      }
    | undefined;
};
