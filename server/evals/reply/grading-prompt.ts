// llm-rubric の判定の指示（promptfoo の rubricPrompt）。既定の指示は返事しか見せないので、数字が渡した値か、記録に触れているかを判定できるよう、
// 返事を作るときに渡した文脈（vars.contextText）も見せる。{{ }} は promptfoo が nunjucks で埋める
export const gradingPrompt = JSON.stringify([
  {
    role: "system",
    content: [
      "あなたは、食事と体重の記録アプリが使う人に返した返事を、守ることの1項目について判定します。",
      "<Context> は、アプリが返事を作るときに渡した文脈（直近の会話と記録、記録の値、いま応える発言）です。<Output> は返事の本文です。<Rubric> は守ることの1項目です。",
      "返事が <Rubric> の文のとおりなら pass を true と score を 1 に、そうでなければ pass を false と score を 0 にします。<Rubric> にかかわらない点では判定しません。",
      "reason には、判断の根拠を、返事の文を引いて日本語で1〜2文で書きます。",
    ].join("\n"),
  },
  {
    role: "user",
    content:
      "<Context>\n{{ contextText }}\n</Context>\n<Output>\n{{ output }}\n</Output>\n<Rubric>\n{{ rubric }}\n</Rubric>",
  },
]);
