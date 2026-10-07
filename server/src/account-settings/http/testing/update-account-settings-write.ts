import { generateRecordId } from "../../../domain/record-id";

export const updateAccountSettingsWrite = (
  overrides: { id?: string; accountSettings?: Record<string, unknown> } = {},
): { id: string; type: "update_account_settings"; accountSettings: Record<string, unknown> } => ({
  id: overrides.id ?? generateRecordId(),
  type: "update_account_settings",
  accountSettings: {
    id: accountSettings1,
    sendsUsageData: false,
    ...overrides.accountSettings,
  },
});

// 呼ぶたびに同じ記録を指すよう、ID はモジュールで1つだけ振る
const accountSettings1 = generateRecordId();
