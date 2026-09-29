export const isTimeZoneName = (timeZone: string): boolean => {
  try {
    Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
};
