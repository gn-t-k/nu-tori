// 規約の版。出した順に並べ、新しい版を出したら末尾に足して、今の版を書き換える。
// 版の文字列は、端末がサインインの画面と同意のシートで送る値
const termsVersions = ["1"] as const;

export type TermsVersion = (typeof termsVersions)[number];

// 今の規約の版。サインインの画面で見せ、同意のシートで同意を求める
export const currentTermsVersion: TermsVersion = "1";

// 同意を取り直す版。この版か、より後の版のどれかに同意していれば、同意は要らない。
// 不利な変更で版を足したときだけ、その版へ上げる
const reconsentRequiredFromVersion: TermsVersion = "1";

export const isTermsVersion = (value: string): value is TermsVersion =>
  termsVersions.some((version) => version === value);

// 同意を取り直す版と、それより後の版
export const termsVersionsSatisfyingAgreement: readonly TermsVersion[] = termsVersions.slice(
  termsVersions.indexOf(reconsentRequiredFromVersion),
);
