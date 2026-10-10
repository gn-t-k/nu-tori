import { beforeEach, describe, expect, test } from "vitest";
import type { ReplyContext } from "../reply-context";
import { assembleReplyContext } from "./index";
import { buildReplyContextSource as build } from "./testing/build-reply-context-source";

describe("返事に渡す文脈の組み立て", () => {
  describe("日の基準", () => {
    describe("ニューヨークで送った文章が、日本時間では翌日に届いたとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            // ニューヨークの 10/9（金）22:30。日本時間では 10/10 11:30
            sentText: {
              ...build.sentText(1, "2026-10-10T02:30:00Z", "今日どうだった？"),
              timeZone: "America/New_York",
            },
            meals: [
              // ニューヨークの 10/9 の夜に食べた食事（時差 -04:00）
              {
                ...build.meal(2, "2026-10-09T23:00:00Z"),
                meal: {
                  ...build.meal(2, "2026-10-09T23:00:00Z").meal,
                  eatenAtUtcOffsetSeconds: -4 * 60 * 60,
                },
              },
            ],
          }),
        );
      });

      test("送った文章の時刻とタイムゾーンでの日時と曜日を、送った日時にすること", () => {
        expect(context.structuredValues.sentAt).toEqual({
          at: "2026-10-09T22:30",
          dayOfWeek: "金",
        });
      });

      test("送った文章のタイムゾーンでの日の食事を、今日の食事にすること", () => {
        expect(context.structuredValues.todayMeals.map(({ mealId }) => mealId)).toEqual([
          build.id(2),
        ]);
      });

      test("応える文章を新しい発言にすること", () => {
        expect(context.newUtterance).toEqual({ at: "2026-10-09T22:30", body: "今日どうだった？" });
      });
    });
  });

  describe("文脈の窓", () => {
    // 応える文章は 2026-10-10 12:00（東京）= 03:00Z
    const answeredAt = "2026-10-10T03:00:00Z";
    const minutesBefore = (minutes: number): string =>
      new Date(Date.parse(answeredAt) - minutes * 60 * 1000).toISOString();

    describe("72 時間より前の発言と、72 時間以内の発言があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [
              build.conversation(2, "2026-10-07T02:59:00Z"),
              build.conversation(3, "2026-10-07T06:00:00Z"),
            ],
          }),
        );
      });

      test("72 時間以内の発言だけを入れること", () => {
        expect(context.window).toEqual([
          { type: "user_utterance", at: "2026-10-07T15:00", body: "文章3" },
        ]);
      });
    });

    describe("72 時間以内だが、窓の始まりの段より前の発言があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            // 70 時間前。72 時間前（10/07 03:00Z）を 6 時間の区切りに切り上げた 06:00Z より前
            sentTexts: [build.conversation(2, "2026-10-07T05:00:00Z")],
          }),
        );
      });

      test("段より前の発言を入れないこと", () => {
        expect(context.window).toEqual([]);
      });
    });

    describe("72 時間以内に 20 発言あるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: Array.from({ length: 10 }, (_, index) =>
              build.conversation(index + 2, minutesBefore(100 - index), `返事${index + 2}`),
            ),
          }),
        );
      });

      test("20 発言をすべて入れること", () => {
        expect(context.window).toHaveLength(20);
      });
    });

    describe("72 時間以内に 21 発言あるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: Array.from({ length: 21 }, (_, index) =>
              build.conversation(index + 2, minutesBefore(100 - index)),
            ),
          }),
        );
      });

      test("始まりを 10 発言進め、新しいほうの 11 発言を入れること", () => {
        expect(context.window.map((entry) => "body" in entry && entry.body)).toEqual(
          Array.from({ length: 11 }, (_, index) => `文章${index + 12}`),
        );
      });
    });

    describe("21 発言のあとに、もう1つ発言してから応えるとき", () => {
      let before: ReplyContext;
      let after: ReplyContext;
      beforeEach(() => {
        const sentTexts = Array.from({ length: 21 }, (_, index) =>
          build.conversation(index + 2, minutesBefore(100 - index)),
        );
        before = assembleReplyContext(
          build.source({ sentText: build.sentText(100, minutesBefore(50)), sentTexts }),
        );
        after = assembleReplyContext(
          build.source({
            sentText: build.sentText(101, answeredAt),
            sentTexts: [...sentTexts, build.conversation(100, minutesBefore(50))],
          }),
        );
      });

      test("始まりを動かさず、前の窓の末尾に足すこと", () => {
        expect(after.window.slice(0, before.window.length)).toEqual(before.window);
        expect(after.window).toHaveLength(before.window.length + 1);
      });
    });

    describe("応える文章が、ほかの送った文章と一緒に渡されたとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt, "今の"),
            sentTexts: [
              build.conversation(2, minutesBefore(30), "返事2"),
              {
                ...build.conversation(1, answeredAt),
                sentText: build.sentText(1, answeredAt, "今の"),
              },
            ],
          }),
        );
      });

      test("応える文章を窓に入れず、新しい発言に置くこと", () => {
        expect(context.window).toEqual([
          { type: "user_utterance", at: "2026-10-10T11:30", body: "文章2" },
          { type: "ai_utterance", at: "2026-10-10T11:30", body: "返事2" },
        ]);
        expect(context.newUtterance.body).toBe("今の");
      });
    });

    describe("食事と読み分けたままの文章から作った食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [
              build.conversation(2, minutesBefore(120), "返事2"),
              {
                sentText: build.sentText(3, minutesBefore(60), "親子丼食べた"),
                replyRequest: undefined,
              },
            ],
            meals: [
              {
                ...build.meal(4, minutesBefore(90), [build.dish("親子丼", [])], minutesBefore(60)),
                meal: {
                  ...build.meal(4, minutesBefore(90), [], minutesBefore(60)).meal,
                  entryMethod: "written",
                  photoIds: [],
                },
              },
            ],
          }),
        );
      });

      test("文章を発言に入れず、その食事を ID つきの記録の印にすること", () => {
        expect(context.window).toEqual([
          { type: "user_utterance", at: "2026-10-10T10:00", body: "文章2" },
          { type: "ai_utterance", at: "2026-10-10T10:00", body: "返事2" },
          {
            type: "meal_recorded",
            at: "2026-10-10T11:00",
            mealId: build.id(4),
            eatenAt: "2026-10-10T10:30",
            dishNames: ["親子丼"],
          },
        ]);
      });
    });

    describe("発言のあいだに食事と体重記録が入ったとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [
              build.conversation(2, minutesBefore(300), "返事2"),
              build.conversation(3, minutesBefore(100)),
            ],
            meals: [
              build.meal(4, minutesBefore(400), [build.dish("トースト", [])]),
              build.meal(5, minutesBefore(40), [
                build.dish("親子丼", []),
                build.dish("味噌汁", []),
              ]),
              build.meal(6, minutesBefore(200), [build.dish("おにぎり", [])]),
            ],
            weightRecords: [
              build.weightRecord(7, minutesBefore(250), 72.4),
              build.weightRecord(8, minutesBefore(150), 72.1, {
                sourceAppName: "体重計",
                sourceBundleId: "com.example.scale",
                healthkitSampleUuid: "00000000-0000-4000-8000-000000000099",
                bodyFat: undefined,
              }),
            ],
          }),
        );
      });

      test("最初の発言から後の、使う人が入れた記録を、時刻の順に記録の印で挟むこと", () => {
        expect(context.window).toEqual([
          { type: "user_utterance", at: "2026-10-10T07:00", body: "文章2" },
          { type: "ai_utterance", at: "2026-10-10T07:00", body: "返事2" },
          { type: "weight_recorded", at: "2026-10-10T07:50", weightKg: 72.4 },
          {
            type: "meal_recorded",
            at: "2026-10-10T08:40",
            mealId: build.id(6),
            eatenAt: "2026-10-10T08:40",
            dishNames: ["おにぎり"],
          },
          { type: "user_utterance", at: "2026-10-10T10:20", body: "文章3" },
          {
            type: "meal_recorded",
            at: "2026-10-10T11:20",
            mealId: build.id(5),
            eatenAt: "2026-10-10T11:20",
            dishNames: ["親子丼", "味噌汁"],
          },
        ]);
      });
    });
  });

  describe("構造化した値", () => {
    // 応える文章は 2026-10-10（土）12:00（東京）
    const answeredAt = "2026-10-10T03:00:00Z";

    describe("今日と昨日と 7 日より前に食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            meals: [
              build.meal(2, "2026-10-09T23:30:00Z", [
                build.dish("親子丼", [
                  build.ingredient("鶏もも肉", 100, { energy_kcal: 200, protein_g: 20, fat_g: 10 }),
                  build.ingredient("ごはん", 200, {
                    energy_kcal: 150,
                    protein_g: 2,
                    carbohydrate_g: 35,
                  }),
                ]),
              ]),
              build.meal(3, "2026-10-09T10:00:00Z", [build.dish("カレー", [])]),
              build.meal(4, "2026-10-08T10:00:00Z", [
                build.dish("そば", [
                  build.ingredient("そば", 200, {
                    energy_kcal: 130,
                    protein_g: 5,
                    fat_g: 1,
                    carbohydrate_g: 26,
                  }),
                ]),
              ]),
              build.meal(5, "2026-10-02T10:00:00Z", [build.dish("ラーメン", [])]),
              // 応える文章より後に送った食事は、送ったときに無かったので入れない
              build.meal(6, "2026-10-10T03:30:00Z", [build.dish("アイス", [])]),
            ],
          }),
        );
      });

      test("今日の食事に、ID・時刻・料理ごとの量と kcal・P・F・C を、不明を含むかと一緒に入れること", () => {
        expect(context.structuredValues.todayMeals).toEqual([
          {
            mealId: build.id(2),
            eatenAt: "2026-10-10T08:30",
            estimation: "settled",
            dishes: [
              {
                name: "親子丼",
                quantity: { value: 1, unit: "杯" },
                nutrients: {
                  energyKcal: { type: "exactly", value: 500 },
                  proteinG: { type: "exactly", value: 24 },
                  fatG: { type: "at_least", value: 10 },
                  carbohydrateG: { type: "at_least", value: 70 },
                },
              },
            ],
          },
        ]);
      });

      test("昨日の食事を ID つきで入れること", () => {
        expect(context.structuredValues.yesterdayMeals).toEqual([
          { mealId: build.id(3), eatenAt: "2026-10-09T19:00", dishNames: ["カレー"] },
        ]);
      });

      test("今日の前の 7 日の、日ごとの合計と記録した日を入れること", () => {
        expect(context.structuredValues.previousDays).toEqual([
          { calendarDay: "2026-10-03", recorded: false },
          { calendarDay: "2026-10-04", recorded: false },
          { calendarDay: "2026-10-05", recorded: false },
          { calendarDay: "2026-10-06", recorded: false },
          { calendarDay: "2026-10-07", recorded: false },
          {
            calendarDay: "2026-10-08",
            recorded: true,
            nutrients: {
              energyKcal: { type: "exactly", value: 260 },
              proteinG: { type: "exactly", value: 10 },
              fatG: { type: "exactly", value: 2 },
              carbohydrateG: { type: "exactly", value: 52 },
            },
          },
          {
            calendarDay: "2026-10-09",
            recorded: true,
            nutrients: {
              energyKcal: { type: "exactly", value: 0 },
              proteinG: { type: "exactly", value: 0 },
              fatG: { type: "exactly", value: 0 },
              carbohydrateG: { type: "exactly", value: 0 },
            },
          },
        ]);
      });
    });

    describe("前の日に、推定の済んだ食事と、推定を待つ食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            meals: [
              build.meal(2, "2026-10-08T10:00:00Z", [
                build.dish("そば", [
                  build.ingredient("そば", 200, {
                    energy_kcal: 130,
                    protein_g: 5,
                    fat_g: 1,
                    carbohydrate_g: 26,
                  }),
                ]),
              ]),
              { ...build.meal(3, "2026-10-08T12:00:00Z"), estimation: "awaiting" },
            ],
          }),
        );
      });

      test("その日の分かる値を「以上」にすること", () => {
        expect(context.structuredValues.previousDays.at(-2)).toEqual({
          calendarDay: "2026-10-08",
          recorded: true,
          nutrients: {
            energyKcal: { type: "at_least", value: 260 },
            proteinG: { type: "at_least", value: 10 },
            fatG: { type: "at_least", value: 2 },
            carbohydrateG: { type: "at_least", value: 52 },
          },
        });
      });
    });

    describe("体重記録と体重の傾向があるとき", () => {
      let context: ReplyContext;
      beforeEach(() => {
        context = assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            weightRecords: [
              build.weightRecord(2, "2026-10-08T22:00:00Z", 72.4),
              build.weightRecord(3, "2026-10-09T22:00:00Z", 72.2, {
                sourceAppName: "体重計",
                sourceBundleId: "com.example.scale",
                healthkitSampleUuid: "00000000-0000-4000-8000-000000000099",
                bodyFat: {
                  percentage: 20,
                  healthkitSampleUuid: "00000000-0000-4000-8000-000000000098",
                },
              }),
              // 応える文章より後の記録は入れない
              build.weightRecord(4, "2026-10-10T04:00:00Z", 71.9),
            ],
            weightTrend: [
              { calendarDay: "2026-09-12", trendKg: 74.0 },
              { calendarDay: "2026-09-13", trendKg: 73.9 },
              { calendarDay: "2026-09-20", trendKg: 73.5 },
              { calendarDay: "2026-09-21", trendKg: 73.4 },
              { calendarDay: "2026-10-01", trendKg: 72.9 },
              { calendarDay: "2026-10-03", trendKg: 72.7 },
            ],
          }),
        );
      });

      test("今日までの 28 日を 7 日ずつに分け、週ごとに最後の傾向の値を入れること", () => {
        expect(context.structuredValues.weeklyWeightTrend).toEqual([
          { firstDay: "2026-09-13", lastDay: "2026-09-19", trendKg: 73.9 },
          { firstDay: "2026-09-20", lastDay: "2026-09-26", trendKg: 73.4 },
          { firstDay: "2026-09-27", lastDay: "2026-10-03", trendKg: 72.7 },
          { firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: undefined },
        ]);
      });

      test("応える文章までの最後の体重記録を、取り込んだものも含めて入れること", () => {
        expect(context.structuredValues.lastWeightRecord).toEqual({
          at: "2026-10-10T07:00",
          weightKg: 72.2,
        });
      });
    });
  });

  describe("渡さないもの", () => {
    let serialized: string;
    beforeEach(() => {
      const answeredAt = "2026-10-10T03:00:00Z";
      serialized = JSON.stringify(
        assembleReplyContext(
          build.source({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [build.conversation(2, "2026-10-10T01:00:00Z", "返事2")],
            meals: [
              build.meal(3, "2026-10-10T02:00:00Z", [
                build.dish("親子丼", [
                  build.ingredient("鶏もも肉", 100, { energy_kcal: 200, vitamin_c_mg: 3 }),
                ]),
              ]),
            ],
            weightRecords: [
              build.weightRecord(4, "2026-10-10T02:30:00Z", 72.2, {
                sourceAppName: "体重計",
                sourceBundleId: "com.example.scale",
                healthkitSampleUuid: "00000000-0000-4000-8000-000000000099",
                bodyFat: {
                  percentage: 20,
                  healthkitSampleUuid: "00000000-0000-4000-8000-000000000098",
                },
              }),
            ],
          }),
        ),
      );
    });

    test("写真・材料の細目・主な栄養より細かい栄養・体脂肪率を入れないこと", () => {
      expect(serialized).not.toContain(build.id(3 + 5000));
      expect(serialized).not.toContain("鶏もも肉");
      expect(serialized).not.toContain("vitamin");
      expect(serialized).not.toContain("bodyFat");
      expect(serialized).not.toContain("percentage");
    });
  });
});
