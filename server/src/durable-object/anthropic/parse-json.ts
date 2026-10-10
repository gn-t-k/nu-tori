// モデルが答えたテキストを JSON として読む。読めないテキストは、形の確かめで落ちるよう undefined にする
export const parseJson = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
};
