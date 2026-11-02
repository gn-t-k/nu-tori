-- 帳簿にサブスクリプションの状態の変更を載せたときの状態（#881）。CREATE だけで、既存の表は変えない。
-- 書き足すだけで、UPDATE も DELETE も無い。取りに来た要求で、今の状態がいちばん新しい行と違うときだけ変更を足す。
-- 状態は JSON の文字列で持ち、読み戻さずに比べるだけにする。行は状態が変わったときにしか増えないので、索引は置かない

CREATE TABLE ledgered_subscription_statuses (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  status TEXT NOT NULL,
  ledgered_at INTEGER NOT NULL
);
