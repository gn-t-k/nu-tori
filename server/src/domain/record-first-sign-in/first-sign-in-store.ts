export type FirstSignInStore = {
  exists: () => boolean;
  insert: (firstSignIn: {
    id: string;
    startedOn: string;
    signedInAt: Date;
    timeZone: string | undefined;
  }) => void;
};
