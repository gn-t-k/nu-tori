// 元に戻せない形にした値（SHA-256 の16進）。提供元に渡すアカウント ID と、Apple の nonce の突き合わせに使う
export const computeSha256Hex = async (value: string): Promise<string> => {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
};
