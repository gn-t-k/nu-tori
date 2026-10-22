import type { SitePage } from "../site-page";

// 問い合わせの入口だけを置く。よくある質問は、同じ問い合わせが2回来たら足す。個人の Gmail のアドレスは出さない
// メールの送り先の案内は、プライバシーポリシーの「外国にある第三者への提供について」の同意の文と合わせて直す
export const supportPage: SitePage = {
  outputPath: "/support",
  title: "サポート | nu-tori",
  description:
    "nu-tori への問い合わせは、問い合わせのフォームか support@nu-tori.app のメールで受け付けます。",
  search: { kind: "indexed", canonicalPath: "/support" },
  Content: () => (
    <>
      <h1>サポート</h1>

      <h2>障害が起きているとき</h2>
      <p>
        アプリが開けないときや、記録が送れないときは、先に<a href="/announcements">告知</a>
        をご覧ください。障害や個人情報の取り扱いについての運営からの告知を、アプリが開けなくても読める形で載せます。
      </p>

      <h2>問い合わせ</h2>
      <p>次のどちらでも受け付けます。</p>
      <ul>
        <li>
          <a href="https://forms.gle/KGg899DaWghiYnTx7">nu-tori 問い合わせフォーム</a>
        </li>
        <li>
          メール: <a href="mailto:support@nu-tori.app">support@nu-tori.app</a>
        </li>
      </ul>
      <p>
        メールは、Google LLC（米国）の Google Workspace
        で受け取り、保存します。米国の個人情報の保護の制度と、Google
        が講じる措置は、プライバシーポリシーの
        <a href="/privacy#overseas-transfer">「外国にある第三者への提供について」</a>
        に書いています。お読みいただいたうえでメールを送っていただいたことで、外国にある第三者への提供に同意いただいたものとします。
      </p>

      <h2>アプリから問い合わせる</h2>
      <p>
        アプリの「アカウント」から問い合わせのフォームを開くと、あなたのアカウント ID
        が添えられます。記録を調べてお答えしやすくなるので、不具合の報告はアプリからお送りください。
      </p>
    </>
  ),
};
