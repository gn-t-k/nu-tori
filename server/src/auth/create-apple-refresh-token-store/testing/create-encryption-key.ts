export const createEncryptionKey = (byte: number): string =>
  btoa(String.fromCharCode(...new Uint8Array(32).fill(byte)));
