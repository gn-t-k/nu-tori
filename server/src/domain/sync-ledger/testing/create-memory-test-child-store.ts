import type { TestChildStore } from "./test-child-kind";

export const createMemoryTestChildStore = (operations: string[]): TestChildStore => {
  const children = new Map<string, { parentId: string; value: number }>();
  const deletedIds = new Set<string>();
  return {
    find: (id) => children.get(id)?.value,
    findIdsOfParent: (parentId) =>
      [...children.entries()].filter(([, child]) => child.parentId === parentId).map(([id]) => id),
    hasDeletion: (id) => deletedIds.has(id),
    insert: ({ id, parentId, value }) => {
      operations.push("child");
      children.set(id, { parentId, value });
    },
    removeWithDeletion: (id) => {
      operations.push("child");
      children.delete(id);
      deletedIds.add(id);
    },
  };
};
