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
  },
};
