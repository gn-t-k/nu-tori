export const isTimeZoneName = (timeZone: string): boolean => {
  // Intl は「+09:00」のような時差も受け付けるが、IANA 名ではない
  if (/^[+-]/u.test(timeZone)) {
    return false;
  }
  try {
    Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
};
