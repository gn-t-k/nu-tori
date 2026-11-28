import { medicalDisclaimer } from "../medical-disclaimer";
import type { SitePage } from "../site-page";
import type { LearnArticle, LearnClaim, LearnSource } from "./learn-article";

// 並び（出会う順）から、一覧と1問ずつのページを作る。
// listed が false のあいだは、どのページも検索に載せず（noindex、sitemap.xml に載らない）、外枠の足にも出さない
export const createLearnPages = (
  articles: readonly LearnArticle[],
  { listed }: { listed: boolean },
): readonly SitePage[] => [
  {
    outputPath: indexPath,
    title: `${indexLabel} | nu-tori`,
    description:
      "「何を食べればいい？」「プロテインを飲めばいいの？」に自分で答えられるようになる、ダイエットの基本。科学的な根拠にもとづく説明と、nu-tori があなたのダイエットをどう助けるかをまとめました。",
    ...(listed ? { kind: "public", footerLabel: indexLabel } : { kind: "unindexed" }),
    Content: () => <LearnIndex articles={articles} />,
  },
  ...articles.map((article, index): SitePage => ({
    outputPath: articlePath(article),
    title: `${article.question} | nu-tori`,
    description: article.description,
    ...(listed ? { kind: "indexed" } : { kind: "unindexed" }),
    Content: () => <LearnArticlePage article={article} next={articles[index + 1]} />,
  })),
];

const indexPath = "/learn";
const indexLabel = "遠回りしないためのダイエットの基本";

const articlePath = (article: LearnArticle) => `${indexPath}/${article.slug}`;

const LearnArticlePage = ({
  article: { question, Lead, claims, sources, decidedByNuTori },
  next,
}: {
  article: LearnArticle;
  next: LearnArticle | undefined;
}) => (
  <>
    <p>
      <a href={indexPath}>{indexLabel}</a>
    </p>
    <h1>{question}</h1>
    <Lead />
    {claims.map((claim) => (
      <Claim claim={claim} />
    ))}
    <h2 id="sources">出典</h2>
    <Sources sources={sources} decidedByNuTori={decidedByNuTori} />
    <p>{medicalDisclaimer}</p>
    <nav>
      <ul>
        {next === undefined ? null : (
          <li>
            次の問い:{" "}
            <a href={articlePath(next)} rel="next">
              {next.question}
            </a>
          </li>
        )}
        <li>
          <a href={indexPath}>{indexLabel}</a>
        </li>
      </ul>
    </nav>
  </>
);

const Claim = ({ claim: { heading, Research, NuTori } }: { claim: LearnClaim }) => (
  <>
    <h2>{heading}</h2>
    <Research />
    {NuTori === undefined ? null : (
      <>
        <h3>nu-tori では</h3>
        <NuTori />
      </>
    )}
  </>
);

const LearnIndex = ({ articles }: { articles: readonly LearnArticle[] }) => (
  <>
    <h1>{indexLabel}</h1>
    <p>
      ダイエットを始めようと思うと、「何を食べればいい？」「プロテインを飲めばいいの？」と考えがちです。栄養の知識・体が変わるメカニズムを知っておくと、その答えも、ほかのいろいろなダイエット法の意味も、自分で考えてわかるようになります。科学的な根拠にもとづく説明と、nu-tori
      があなたのダイエットをどう助けるかをまとめました。
    </p>
    <ol>
      {articles.map((article) => (
        <li>
          <a href={articlePath(article)}>{article.question}</a>
        </li>
      ))}
    </ol>
    {/* 各ページの出典を並びから集める（手で写さない） */}
    <h2 id="sources">出典</h2>
    <Sources
      sources={uniqueBy(
        articles.flatMap((article) => article.sources),
        (source) => source.url,
      )}
      decidedByNuTori={uniqueBy(
        articles.flatMap((article) => article.decidedByNuTori),
        (rule) => rule,
      )}
    />
    <p>{medicalDisclaimer}</p>
  </>
);

const Sources = ({
  sources,
  decidedByNuTori,
}: {
  sources: readonly LearnSource[];
  decidedByNuTori: readonly string[];
}) => (
  <>
    <p>
      nu-tori は、次の資料をもとに書き、決まりを決めました。資料の値をどう当てはめるかは nu-tori
      が決めています。
    </p>
    <ul class="learn-sources">
      {sources.map(({ claim, citation, url, linkLabel }) => (
        <li>
          {claim}: {citation} <a href={url}>{linkLabel}</a>
        </li>
      ))}
    </ul>
    {decidedByNuTori.length === 0 ? null : (
      <>
        <h3>nu-tori が決めたもの</h3>
        <p>
          次の決まりは、資料に拠らず nu-tori
          が決めました。使っていただいた記録を見て、これから直すことがあります。
        </p>
        <ul>
          {decidedByNuTori.map((rule) => (
            <li>{rule}</li>
          ))}
        </ul>
      </>
    )}
  </>
);

// 先に出たものを残す
const uniqueBy = <T,>(items: readonly T[], keyOf: (item: T) => string): readonly T[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = keyOf(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};
