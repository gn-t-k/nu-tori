export type WeightRecord = {
  id: string;
  weightKg: number;
  measuredAt: Date;
  timeZone: string;
  version: number;
  // ヘルスケアから取り込んだ記録だけが持つ。nu-tori で手で記録したものは undefined
  imported:
    | {
        sourceAppName: string;
        sourceBundleId: string;
        healthkitSampleUuid: string;
        bodyFat: { percentage: number; healthkitSampleUuid: string } | undefined;
      }
    | undefined;
};
