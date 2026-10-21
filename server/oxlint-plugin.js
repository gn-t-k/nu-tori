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
          const callback = node.arguments.at(-1);
          if (
            callback === undefined ||
            !isFunction(callback) ||
            callback.body.type !== "BlockStatement"
          ) {
            return;
          }
          // 準備の補助（関数）は、呼ぶまで何も作らないので置いてよい
          for (const statement of callback.body.body) {
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
          const callback = node.arguments.at(-1);
          if (
            callback === undefined ||
            !isFunction(callback) ||
            callback.body.type !== "BlockStatement"
          ) {
            return;
          }
          for (const statement of callback.body.body) {
            if (
              statement.type === "VariableDeclaration" &&
              statement.declarations.some(
                (declarator) => declarator.init?.type === "ObjectExpression",
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

// describe とその skip・only など。each・for の表から作るまとまりは数えない
const isDescribe = (callee) =>
  (callee.type === "Identifier" && callee.name === "describe") ||
  (callee.type === "MemberExpression" &&
    callee.object.type === "Identifier" &&
    callee.object.name === "describe");

// test・it とその skip・only など。each・for の表から作るテストは数えない
const isTest = (callee) =>
  (callee.type === "Identifier" && testNames.has(callee.name)) ||
  (callee.type === "MemberExpression" &&
    callee.object.type === "Identifier" &&
    testNames.has(callee.object.name));

const testNames = new Set(["test", "it"]);

const isMock = (callee) =>
  (callee.type === "Identifier" && /^mock[A-Z]/u.test(callee.name)) ||
  (callee.type === "MemberExpression" &&
    callee.object.type === "Identifier" &&
    callee.object.name === "vi" &&
    callee.property.type === "Identifier" &&
    callee.property.name === "spyOn");

// 名前の文字列。式を埋め込んだテンプレートは、埋め込んだところを抜いた文字で見る
const titleText = (node) => {
  if (node?.type === "Literal" && typeof node.value === "string") {
    return node.value;
  }
  if (node?.type === "TemplateLiteral") {
    return node.quasis.map((quasi) => quasi.value.cooked).join("");
  }
  return undefined;
};
