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
