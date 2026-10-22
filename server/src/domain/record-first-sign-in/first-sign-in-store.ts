export type FirstSignInStore = {
  exists: () => boolean;
  findStartedOn: () => string | undefined;
  // 最初のサインインで届いた、読めたタイムゾーン。届かないか読めなかったら undefined
  findTimeZone: () => string | undefined;
  insert: (firstSignIn: {
    id: string;
    startedOn: string;
    signedInAt: Date;
    timeZone: string | undefined;
  }) => void;
  // 作り直したアカウントの印（無料体験なし）を、最初のサインインに付ける
  excludeFreeTrial: (firstSignInId: string) => void;
};
