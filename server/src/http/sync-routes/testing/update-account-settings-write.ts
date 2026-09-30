export const updateAccountSettingsWrite = (
  overrides: { id?: string; accountSettings?: Record<string, unknown> } = {},
): { id: string; type: "update_account_settings"; accountSettings: Record<string, unknown> } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "update_account_settings",
  accountSettings: {
    id: "account-settings-1",
    sendsUsageData: false,
    ...overrides.accountSettings,
  },
});
