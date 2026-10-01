export type FirstSignInStore = {
  exists: () => boolean;
  findStartedOn: () => string | undefined;
  insert: (firstSignIn: {
    id: string;
    startedOn: string;
    signedInAt: Date;
    timeZone: string | undefined;
  }) => void;
};
