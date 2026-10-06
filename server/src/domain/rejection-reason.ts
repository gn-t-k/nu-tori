export type RejectionReason =
  | "out_of_range"
  | "invalid_time_zone"
  | "version_too_low"
  | "record_not_found"
  | "record_before_started_on"
  | "invalid_entry_method"
  | "duplicate_photo_ids"
  | "photo_already_used"
  | "invalid_notice_type"
  | "invalid_target_on"
  // 推定し直しで料理の材料が置き換わっていた（料理の量の書き込みが前の材料を載せていた、前の材料の量を直そうとした）
  | "ingredients_replaced";
