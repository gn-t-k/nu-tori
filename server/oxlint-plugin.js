// 組み込みのルールで確かめられない好み（docs/agents/languages/typescript.md）を確かめる
export default {
  meta: { name: "nu-tori" },
  rules: {
    "no-switch-statement": {
      create: (context) => ({
        SwitchStatement: (node) => {
          context.report({
            node,
            message:
              "switch は使わず、ts-pattern の match(...).exhaustive() で分ける（docs/agents/languages/typescript.md「関数は処理の流れで分ける」）",
          });
        },
      }),
    },
    "no-setup-in-describe": {
      create: (context) => ({
        CallExpression: (node) => {
          if (!isDescribe(node.callee)) {
            return;
          }
          // 準備の補助（関数）は、呼ぶまで何も作らないので置いてよい
          for (const statement of callbackStatements(node)) {
            if (
              statement.type === "VariableDeclaration" &&
              statement.declarations.some(
                (declarator) => declarator.init !== null && !isFunction(declarator.init),
              )
            ) {
              context.report({
                node: statement,
                message:
                  "入力と準備は、describe の直下で作らず、beforeEach で作る。describe の直下には、let の宣言と準備の補助の関数だけを置く（docs/agents/testing.md「テストの構造」）",
              });
            }
          }
        },
      }),
    },
    "no-mock-in-test": {
      create: (context) => ({
        CallExpression: (node) => {
          if (!isMock(node.callee)) {
            return;
          }
          for (let ancestor = node.parent; ancestor; ancestor = ancestor.parent) {
            if (ancestor.type === "CallExpression" && isTest(ancestor.callee)) {
              context.report({
                node,
                message:
                  "依存の差し替え（mockXxx・vi.spyOn）は、テストの本体で呼ばず、その条件の describe の beforeEach で呼ぶ（docs/agents/testing.md「テストの構造」、docs/agents/languages/typescript.md「依存の差し替え」）",
              });
              return;
            }
          }
        },
      }),
    },
    "no-object-in-test": {
      create: (context) => ({
        CallExpression: (node) => {
          if (!isTest(node.callee)) {
            return;
          }
          for (const statement of callbackStatements(node)) {
            if (
              statement.type === "VariableDeclaration" &&
              statement.declarations.some(
                (declarator) => withoutTypeAssertion(declarator.init)?.type === "ObjectExpression",
              )
            ) {
              context.report({
                node: statement,
                message:
                  "入力と準備のオブジェクトは、テストの本体に置かず、その条件の describe の beforeEach で作る。テストの本体は、振る舞いの実行と検証だけにする（docs/agents/testing.md「テストの構造」）",
              });
            }
          }
        },
      }),
    },
    "test-title-ends-with-koto": {
      create: (context) => ({
        CallExpression: (node) => {
          if (!isTest(node.callee)) {
            return;
          }
          const title = titleText(node.arguments[0]);
          // 「〜こと（1つのトランザクションで書く）」のような後ろの補足は許す
          if (title !== undefined && !/こと(（[^）]*）)?$/u.test(title)) {
            context.report({
              node: node.arguments[0],
              message:
                "テストの名前は「〜こと」の形で振る舞いを書く。後ろに「（…）」の補足を付けてよい（docs/agents/testing.md「テストの構造」）",
            });
          }
        },
      }),
    },
    "japanese-describe-title": {
      create: (context) => ({
        CallExpression: (node) => {
          if (!isDescribe(node.callee)) {
            return;
          }
          const title = titleText(node.arguments[0]);
          if (
            title !== undefined &&
            !/[\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Han}]/u.test(title)
          ) {
            context.report({
              node: node.arguments[0],
              message: "まとまりの名前は日本語で書く（docs/agents/testing.md「テストの構造」）",
            });
          }
        },
      }),
    },
    "filename-matches-export": {
      create: (context) => ({
        Program: (node) => {
          const names = localExportNames(node);
          // export default だけの設定ファイルと、再 export だけの index.ts は、比べる名前を持たない
          if (names.length === 0) {
            return;
          }
          const fileName = context.filename.split("/").at(-1).split(".")[0];
          if (names.some((name) => sameWords(name, fileName))) {
            return;
          }
          context.report({
            node,
            message: `ファイル名「${fileName}」を、export する名前（${names.join("、")}）のどれかのケバブケースにする（docs/agents/languages/typescript.md「ファイルと公開するもの」）`,
          });
        },
      }),
    },
    "no-random-uuid": {
      create: (context) => ({
        MemberExpression: (node) => {
          if (
            node.object.type === "Identifier" &&
            node.object.name === "crypto" &&
            node.property.type === "Identifier" &&
            node.property.name === "randomUUID"
          ) {
            context.report({
              node,
              message:
                "DB と API に出す ID は src/domain/record-id の generateRecordId で振る。綴りを小文字の正規形にそろえる口を1つにするため（#362）",
            });
          }
        },
      }),
    },
  },
};

const isFunction = (node) =>
  node.type === "ArrowFunctionExpression" || node.type === "FunctionExpression";

const isDescribe = (callee) => isPlainCallOf(callee, ["describe"]);

const isTest = (callee) => isPlainCallOf(callee, ["test", "it"]);

// each・for の表から作るまとまりとテストは、決まりが許す使い方と見分けられないので数えない（#691）
const isPlainCallOf = (callee, names) =>
  (callee.type === "Identifier" && names.includes(callee.name)) ||
  (callee.type === "MemberExpression" &&
    callee.object.type === "Identifier" &&
    names.includes(callee.object.name) &&
    callee.property.type === "Identifier" &&
    !["each", "for"].includes(callee.property.name));

const callbackStatements = (node) => {
  const callback = node.arguments.at(-1);
  if (callback === undefined || !isFunction(callback) || callback.body.type !== "BlockStatement") {
    return [];
  }
  return callback.body.body;
};

const withoutTypeAssertion = (node) =>
  node?.type === "TSAsExpression" || node?.type === "TSSatisfiesExpression"
    ? withoutTypeAssertion(node.expression)
    : node;

const isMock = (callee) =>
  (callee.type === "Identifier" && /^mock[A-Z]/u.test(callee.name)) ||
  (callee.type === "MemberExpression" &&
    callee.object.type === "Identifier" &&
    callee.object.name === "vi" &&
    callee.property.type === "Identifier" &&
    callee.property.name === "spyOn");

// 埋め込んだ式の値はリントの時点では分からないので、テンプレートは書いた文字だけで見る
const titleText = (node) => {
  if (node?.type === "Literal" && typeof node.value === "string") {
    return node.value;
  }
  if (node?.type === "TemplateLiteral") {
    return node.quasis.map((quasi) => quasi.value.cooked).join("");
  }
  return undefined;
};

// export { x } from "./x" と export * from は、ほかのファイルが出すものなので数えない。
// export { x as default } は export default x と同じく名前を持たないので数えない
const localExportNames = (program) =>
  program.body
    .filter((statement) => statement.type === "ExportNamedDeclaration" && statement.source === null)
    .flatMap((statement) =>
      statement.declaration === null
        ? statement.specifiers.map((specifier) => moduleExportName(specifier.exported))
        : declaredNames(statement.declaration),
    )
    .filter((name) => name !== "default");

const declaredNames = (declaration) =>
  declaration.type === "VariableDeclaration"
    ? declaration.declarations.flatMap((declarator) =>
        declarator.id.type === "Identifier" ? [declarator.id.name] : [],
      )
    : declaration.id?.type === "Identifier"
      ? [declaration.id.name]
      : [];

const moduleExportName = (node) => (node.type === "Identifier" ? node.name : node.value);

// ケバブケースのファイル名と、キャメルケース・パスカルケースの名前を、区切りと大文字小文字を除いて比べる
const sameWords = (name, fileName) =>
  name.toLowerCase() === fileName.replaceAll("-", "").toLowerCase();
