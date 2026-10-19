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
