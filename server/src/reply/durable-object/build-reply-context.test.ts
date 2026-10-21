import { beforeEach, describe, expect, test } from "vitest";
import type { Goal } from "../../goal/domain/goal";
import type { ReplyContext } from "../domain/reply-context";
import { buildReplyContextInAccount } from "./testing/build-reply-context-in-account";
import { buildReplyContextRecords as build } from "./testing/build-reply-context-records";

type Records = Parameters<typeof buildReplyContextInAccount>[0];

// 返事は、送った少しあとのアラームで作る。応える文章のあとに入った記録も、置き場から読める時刻にする
const replyAlarmAt = (sentAt: string): Date => new Date(Date.parse(sentAt) + 60 * 60 * 1000);

describe("返事に渡す文脈の組み立て", () => {
  describe("日の基準", () => {
    describe("ニューヨークで送った文章が、日本時間では翌日に届いたとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // ニューヨークの 10/9（金）22:30。日本時間では 10/10 11:30
        const sentAt = "2026-10-10T02:30:00Z";
        const meal = build.meal(2, "2026-10-09T23:00:00Z");
        context = await buildReplyContextInAccount(
          build.records({
            sentText: {
              ...build.sentText(1, sentAt, "今日どうだった？"),
              timeZone: "America/New_York",
            },
            // ニューヨークの 10/9 の夜に食べた食事（時差 -04:00）
            meals: [{ ...meal, meal: { ...meal.meal, eatenAtUtcOffsetSeconds: -4 * 60 * 60 } }],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("送った文章の時刻とタイムゾーンでの日時と曜日を、送った日時にすること", () => {
        expect(context.structuredValues.sentAt).toEqual({
          at: "2026-10-09T22:30",
          dayOfWeek: "friday",
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
    let answeredAt: string;
    beforeEach(() => {
      answeredAt = "2026-10-10T03:00:00Z";
    });
    const minutesBefore = (minutes: number): string =>
      new Date(Date.parse(answeredAt) - minutes * 60 * 1000).toISOString();

    describe("72 時間より前の発言と、窓の始まりの段ちょうどの発言があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [
              build.conversation(2, "2026-10-07T02:59:00Z"),
              // 72 時間前（10/07 03:00Z）を 6 時間の区切りに切り上げた時刻
              build.conversation(3, "2026-10-07T06:00:00Z"),
            ],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("段ちょうどからの発言だけを入れること", () => {
        expect(context.window).toEqual([
          { type: "user_utterance", at: "2026-10-07T15:00", body: "文章3" },
        ]);
      });
    });

    describe("72 時間以内だが、窓の始まりの段の直前の発言があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            // 段（10/07 06:00Z）の 1 分前
            sentTexts: [build.conversation(2, "2026-10-07T05:59:00Z")],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("段より前の発言を入れないこと", () => {
        expect(context.window).toEqual([]);
      });
    });

    describe("72 時間以内に 20 発言あるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            sentTexts: Array.from({ length: 10 }, (_, index) =>
              build.conversation(index + 2, minutesBefore(100 - index), `返事${index + 2}`),
            ),
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("20 発言をすべて入れること", () => {
        expect(context.window).toHaveLength(20);
      });
    });

    describe("72 時間以内に 21 発言あるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            sentTexts: Array.from({ length: 21 }, (_, index) =>
              build.conversation(index + 2, minutesBefore(100 - index)),
            ),
          }),
          replyAlarmAt(answeredAt),
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
      beforeEach(async () => {
        const sentTexts = Array.from({ length: 21 }, (_, index) =>
          build.conversation(index + 2, minutesBefore(100 - index)),
        );
        before = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(100, minutesBefore(50)), sentTexts }),
          replyAlarmAt(minutesBefore(50)),
        );
        after = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(101, answeredAt),
            sentTexts: [...sentTexts, build.conversation(100, minutesBefore(50))],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("始まりを動かさず、前の窓の末尾に足すこと", () => {
        expect(after.window.slice(0, before.window.length)).toEqual(before.window);
        expect(after.window).toHaveLength(before.window.length + 1);
      });
    });

    describe("応える文章の前に、返事のある発言があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt, "今の"),
            sentTexts: [build.conversation(2, minutesBefore(30), "返事2")],
          }),
          replyAlarmAt(answeredAt),
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
      beforeEach(async () => {
        const meal = build.meal(
          4,
          minutesBefore(90),
          [build.dish("親子丼", [])],
          minutesBefore(60),
        );
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            sentTexts: [
              build.conversation(2, minutesBefore(120), "返事2"),
              build.mealText(3, minutesBefore(60), "親子丼食べた"),
            ],
            meals: [
              {
                ...meal,
                meal: {
                  ...meal.meal,
                  entryMethod: "written",
                  photoIds: [],
                  sentTextId: build.id(3),
                },
              },
            ],
          }),
          replyAlarmAt(answeredAt),
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
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
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
          replyAlarmAt(answeredAt),
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
    let answeredAt: string;
    beforeEach(() => {
      answeredAt = "2026-10-10T03:00:00Z";
    });

    describe("今日と昨日と 7 日より前に食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
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
          replyAlarmAt(answeredAt),
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

      // 返事を作るモデルに足し算をさせない（#434 の評価で、合計を足し間違えた）
      test("今日の食事の合計を入れること", () => {
        expect(context.structuredValues.todayNutrients).toEqual({
          energyKcal: { type: "exactly", value: 500 },
          proteinG: { type: "exactly", value: 24 },
          fatG: { type: "at_least", value: 10 },
          carbohydrateG: { type: "at_least", value: 70 },
        });
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

    describe("夜遅くに送った文章で、時差の大きい地域で今日の 7 日前の始まりに食べた食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/10 23:30（東京）。今日の 7 日前は 10/03
        const sentAt = "2026-10-10T14:30:00Z";
        // キリバスの 10/03 0:30（時差 +14:00）に食べて送った。応える文章の 8 日と 4 時間前
        const meal = build.meal(2, "2026-10-02T10:30:00Z");
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            meals: [{ ...meal, meal: { ...meal.meal, eatenAtUtcOffsetSeconds: 14 * 60 * 60 } }],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("その食事を、前の日のいちばん古い日に数えること", () => {
        expect(context.structuredValues.previousDays[0]).toEqual({
          calendarDay: "2026-10-03",
          recorded: true,
          nutrients: {
            energyKcal: { type: "exactly", value: 0 },
            proteinG: { type: "exactly", value: 0 },
            fatG: { type: "exactly", value: 0 },
            carbohydrateG: { type: "exactly", value: 0 },
          },
        });
      });
    });

    describe("今日の食事がまだ無いとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, answeredAt) }),
          replyAlarmAt(answeredAt),
        );
      });

      test("今日の食事の合計を入れないこと", () => {
        expect(context.structuredValues.todayNutrients).toBeUndefined();
      });
    });

    describe("今日の食事に、推定の済んだ食事と、推定を待つ食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            meals: [
              build.meal(2, "2026-10-09T23:30:00Z", [
                build.dish("そば", [
                  build.ingredient("そば", 200, {
                    energy_kcal: 130,
                    protein_g: 5,
                    fat_g: 1,
                    carbohydrate_g: 26,
                  }),
                ]),
              ]),
              { ...build.meal(3, "2026-10-10T01:00:00Z"), estimation: "awaiting" },
            ],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("推定を待つ食事を、推定しているところにすること", () => {
        expect(
          context.structuredValues.todayMeals.map(({ mealId, estimation }) => ({
            mealId,
            estimation,
          })),
        ).toEqual([
          { mealId: build.id(2), estimation: "settled" },
          { mealId: build.id(3), estimation: "awaiting" },
        ]);
      });

      test("今日の食事の合計の分かる値を「以上」にすること", () => {
        expect(context.structuredValues.todayNutrients).toEqual({
          energyKcal: { type: "at_least", value: 260 },
          proteinG: { type: "at_least", value: 10 },
          fatG: { type: "at_least", value: 2 },
          carbohydrateG: { type: "at_least", value: 52 },
        });
      });
    });

    describe("今日の食事に、推定できなかった食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            meals: [{ ...build.meal(2, "2026-10-10T01:00:00Z"), estimation: "failed" }],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("その食事を、推定できなかったにすること", () => {
        expect(context.structuredValues.todayMeals.map(({ estimation }) => estimation)).toEqual([
          "failed",
        ]);
      });
    });

    describe("前の日に、推定の済んだ食事と、推定を待つ食事があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
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
          replyAlarmAt(answeredAt),
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

    describe("応える文章の前とあとに体重記録があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
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
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("応える文章までの最後の体重記録を、取り込んだものも含めて入れること", () => {
        expect(context.structuredValues.lastWeightRecord).toEqual({
          at: "2026-10-10T07:00",
          weightKg: 72.2,
        });
      });
    });

    describe("体重記録が、今日の 7 日前より前にしか無いとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            weightRecords: [build.weightRecordOn(2, "2026-09-20", 73.1)],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("その記録を最後の体重記録に入れること", () => {
        expect(context.structuredValues.lastWeightRecord).toEqual({
          at: "2026-09-20T09:00",
          weightKg: 73.1,
        });
      });
    });

    describe("今日までの 28 日の体重記録から、体重の傾向が出るとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, answeredAt),
            // 傾向は 9/19 まで 74.0 kg。そのあと 10/03 の 72.6 kg に向けて重み 0.1 でならす
            weightRecords: [
              build.weightRecordOn(2, "2026-09-12", 74.0),
              build.weightRecordOn(3, "2026-09-19", 74.0),
              build.weightRecordOn(4, "2026-10-03", 72.6),
            ],
          }),
          replyAlarmAt(answeredAt),
        );
      });

      test("今日までの 28 日を 7 日ずつに分け、週ごとに最後の傾向の値を入れること", () => {
        expect(context.structuredValues.weeklyWeightTrend).toEqual([
          { firstDay: "2026-09-13", lastDay: "2026-09-19", trendKg: 74.0 },
          { firstDay: "2026-09-20", lastDay: "2026-09-26", trendKg: expect.closeTo(73.7695, 4) },
          { firstDay: "2026-09-27", lastDay: "2026-10-03", trendKg: expect.closeTo(73.2941, 4) },
          { firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: undefined },
        ]);
      });
    });
  });

  describe("目標と1日の目安と推定消費カロリー", () => {
    // 10/03 に減量の目標を立て、10/10 に立て直した。どちらの日にも推定がある
    let goalRecords: Pick<Records, "goals" | "dailyGuides" | "expenditureEstimates">;
    beforeEach(() => {
      const firstGoal = build.goal(10, "2026-10-03", {
        targetWeightKg: 70,
        weightChange: { deadlineOn: "2027-01-01", pacePlan: "standard" },
        closure: { endedOn: "2026-10-10", nextGoalId: build.id(11), endReason: "switched" },
      });
      const secondGoal = build.goal(11, "2026-10-10", {
        targetWeightKg: 68.5,
        weightChange: { deadlineOn: "2027-02-01", pacePlan: "gentle" },
      });
      goalRecords = {
        goals: [firstGoal, secondGoal],
        dailyGuides: [
          build.dailyGuide(
            20,
            { goalId: firstGoal.id, expenditureEstimateId: build.id(120) },
            "2026-10-03",
            1900,
          ),
          build.dailyGuide(
            21,
            { goalId: secondGoal.id, expenditureEstimateId: build.id(121) },
            "2026-10-10",
            2000,
          ),
        ],
        expenditureEstimates: [
          build.expenditureEstimate(120, "2026-10-03", 2400),
          build.expenditureEstimate(121, "2026-10-10", 2350),
        ],
      };
    });

    describe("その日を含む目標があるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/10 12:00（東京）
        const sentAt = "2026-10-10T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...goalRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("その日を含む目標の向き・期限・目標体重と、その日の1日の目安と推定消費カロリーを入れること", () => {
        expect(context.structuredValues.goal).toEqual({
          direction: "lose",
          deadlineOn: "2027-02-01",
          targetWeightKg: 68.5,
          dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
          expenditureKcal: 2350,
          latestWeeklyReview: undefined,
          pace: undefined,
        });
      });
    });

    describe("立て直す前の日の文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/09 12:00（東京）
        const sentAt = "2026-10-09T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...goalRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("前の目標と、その日以前で始まりの日が最も遅い推定を入れること", () => {
        expect(context.structuredValues.goal).toEqual({
          direction: "lose",
          deadlineOn: "2027-01-01",
          targetWeightKg: 70,
          dailyGuide: { energyKcal: 1900, proteinG: 105, fatG: 55, carbohydrateG: 270 },
          expenditureKcal: 2400,
          latestWeeklyReview: undefined,
          pace: undefined,
        });
      });
    });

    describe("維持の目標のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/10 12:00（東京）
        const sentAt = "2026-10-10T03:00:00Z";
        const goal = build.goal(10, "2026-10-03", { targetWeightKg: 72, weightChange: undefined });
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            goals: [goal],
            dailyGuides: [
              build.dailyGuide(
                20,
                { goalId: goal.id, expenditureEstimateId: build.id(120) },
                "2026-10-03",
                2400,
              ),
            ],
            expenditureEstimates: [build.expenditureEstimate(120, "2026-10-03", 2400)],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("向きを維持にし、期限を入れないこと", () => {
        expect(context.structuredValues.goal).toMatchObject({
          direction: "maintain",
          deadlineOn: undefined,
          targetWeightKg: 72,
        });
      });
    });

    describe("目標を立てる前の日の文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/02 12:00（東京）
        const sentAt = "2026-10-02T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...goalRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("目標も1日の目安も推定消費カロリーも入れないこと", () => {
        expect(context.structuredValues.goal).toBeUndefined();
      });
    });
  });

  describe("直近の週の見直し", () => {
    // 10/03（土）に減量の目標を立て、10/05（月）に見直し、10/12（月）は見送った
    let reviewRecords: Pick<
      Records,
      "goals" | "dailyGuides" | "expenditureEstimates" | "weeklyReviews"
    >;
    let goal: Goal;
    beforeEach(() => {
      goal = build.goal(10, "2026-10-03", {
        targetWeightKg: 70,
        weightChange: { deadlineOn: "2027-01-01", pacePlan: "standard" },
      });
      reviewRecords = {
        goals: [goal],
        dailyGuides: [
          build.dailyGuide(
            20,
            { goalId: goal.id, expenditureEstimateId: build.id(120) },
            "2026-10-03",
            1900,
          ),
          build.dailyGuide(
            21,
            { goalId: goal.id, expenditureEstimateId: build.id(121) },
            "2026-10-05",
            1850,
            ["weekly_change"],
          ),
        ],
        expenditureEstimates: [
          build.expenditureEstimate(120, "2026-10-03", 2400),
          build.expenditureEstimate(121, "2026-10-05", 2330),
        ],
        weeklyReviews: [
          build.weeklyReview(40, "2026-10-05", {
            type: "reviewed",
            expenditureEstimateId: build.id(121),
            dailyGuideId: build.id(21),
            mainReason: "expenditure_change",
          }),
          build.weeklyReview(41, "2026-10-12", {
            type: "deferred",
            reason: "few_meal_records",
            goalId: goal.id,
          }),
        ],
      };
    });

    describe("見直せた週のあとの文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/07 12:00（東京）
        const sentAt = "2026-10-07T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...reviewRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("見直した週の月曜、当たった上限と下限、主な理由、前の週からの1日の目安と推定消費カロリーの変化を入れること", () => {
        expect(context.structuredValues.goal?.latestWeeklyReview).toEqual({
          type: "reviewed",
          effectiveOn: "2026-10-05",
          limitHits: ["weekly_change"],
          mainReason: "expenditure_change",
          dailyGuideChangeKcal: -50,
          expenditureChangeKcal: -70,
        });
      });
    });

    describe("見送った週のあとの文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/13 12:00（東京）
        const sentAt = "2026-10-13T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...reviewRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("見送った週の月曜と理由だけを入れること", () => {
        expect(context.structuredValues.goal?.latestWeeklyReview).toEqual({
          type: "deferred",
          effectiveOn: "2026-10-12",
          reason: "few_meal_records",
        });
      });
    });

    describe("目標を立てて、まだ見直していない日の文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/04 12:00（東京）
        const sentAt = "2026-10-04T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({ sentText: build.sentText(1, sentAt), ...reviewRecords }),
          replyAlarmAt(sentAt),
        );
      });

      test("見直しを入れないこと", () => {
        expect(context.structuredValues.goal?.latestWeeklyReview).toBeUndefined();
      });
    });

    describe("見送った月曜に、新しい目標を立てた日の文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/12 12:00（東京）
        const sentAt = "2026-10-12T03:00:00Z";
        const secondGoal = build.goal(11, "2026-10-12", {
          targetWeightKg: 72,
          weightChange: undefined,
        });
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            ...reviewRecords,
            goals: [
              {
                ...goal,
                closure: {
                  endedOn: "2026-10-12",
                  nextGoalId: secondGoal.id,
                  endReason: "switched",
                },
              },
              secondGoal,
            ],
            dailyGuides: [
              ...reviewRecords.dailyGuides,
              build.dailyGuide(
                22,
                { goalId: secondGoal.id, expenditureEstimateId: build.id(121) },
                "2026-10-12",
                2330,
              ),
            ],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("前の目標の見直しを入れないこと", () => {
        expect(context.structuredValues.goal).toMatchObject({
          direction: "maintain",
          latestWeeklyReview: undefined,
          pace: undefined,
        });
      });
    });
  });

  describe("その日のペース", () => {
    // 10/03（土）に、期限 2027/01/01、目標体重 70 kg の減量の目標を立てた
    let goalRecords: Pick<Records, "goals" | "dailyGuides" | "expenditureEstimates">;
    beforeEach(() => {
      const goal = build.goal(10, "2026-10-03", {
        targetWeightKg: 70,
        weightChange: { deadlineOn: "2027-01-01", pacePlan: "standard" },
      });
      goalRecords = {
        goals: [goal],
        dailyGuides: [
          build.dailyGuide(
            20,
            { goalId: goal.id, expenditureEstimateId: build.id(120) },
            "2026-10-03",
            1900,
          ),
        ],
        expenditureEstimates: [build.expenditureEstimate(120, "2026-10-03", 2400)],
      };
    });

    describe("目標を立てて 14 日たち、直近 14 日に体重記録のある日が4日あるとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        // 10/20 12:00（東京）
        const sentAt = "2026-10-20T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            ...goalRecords,
            weightRecords: [
              build.weightRecordOn(2, "2026-10-01", 72),
              build.weightRecordOn(3, "2026-10-06", 72),
              build.weightRecordOn(4, "2026-10-14", 70.4),
              build.weightRecordOn(5, "2026-10-15", 70.2),
              build.weightRecordOn(6, "2026-10-16", 70),
              build.weightRecordOn(7, "2026-10-20", 69.2),
            ],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("文章を送った日で判定した、間に合うかを入れること", () => {
        // 傾向は 10/06 が 72 kg、10/20 が約 70.59 kg。速さは約 −0.71 kg/週、見込みは約 63.2 kg で目標体重に届く
        expect(context.structuredValues.goal?.pace).toEqual({
          status: "onTrack",
          actualKgPerWeek: -0.7,
          requiredKgPerWeek: -0.1,
        });
      });
    });

    describe("直近 14 日に体重記録のある日が2日のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        const sentAt = "2026-10-20T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            ...goalRecords,
            // 10/01 と 10/06 は 14 日の外
            weightRecords: [
              build.weightRecordOn(2, "2026-10-01", 72),
              build.weightRecordOn(3, "2026-10-06", 72),
              build.weightRecordOn(4, "2026-10-07", 71.9),
              build.weightRecordOn(5, "2026-10-19", 71),
            ],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("言い切らないことと、記録のある日数を入れること", () => {
        expect(context.structuredValues.goal?.pace).toEqual({
          status: "inconclusive",
          weightRecordDayCount: 2,
        });
      });
    });

    describe("目標を立てて 14 日たっていない日の文章のとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        const sentAt = "2026-10-16T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            ...goalRecords,
            weightRecords: [
              build.weightRecordOn(2, "2026-10-01", 72),
              build.weightRecordOn(3, "2026-10-06", 72),
            ],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("まだ出ないことを入れること", () => {
        expect(context.structuredValues.goal?.pace).toEqual({ status: "pending" });
      });
    });

    describe("目標の開始の日以前の体重の傾向が無いとき", () => {
      let context: ReplyContext;
      beforeEach(async () => {
        const sentAt = "2026-10-20T03:00:00Z";
        context = await buildReplyContextInAccount(
          build.records({
            sentText: build.sentText(1, sentAt),
            ...goalRecords,
            weightRecords: [
              build.weightRecordOn(2, "2026-10-06", 72),
              build.weightRecordOn(3, "2026-10-20", 71),
            ],
          }),
          replyAlarmAt(sentAt),
        );
      });

      test("ペースを入れないこと", () => {
        expect(context.structuredValues.goal?.pace).toBeUndefined();
      });
    });
  });

  describe("渡さないもの", () => {
    let serialized: string;
    beforeEach(async () => {
      const answeredAt = "2026-10-10T03:00:00Z";
      serialized = JSON.stringify(
        await buildReplyContextInAccount(
          build.records({
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
          replyAlarmAt(answeredAt),
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
