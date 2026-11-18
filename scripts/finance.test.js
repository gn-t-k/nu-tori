// scripts/finance の、App Store Connect の販売レポートからサブスクリプションの数字を出すところを、Apple の列の形の偽の TSV で確かめる
// 値段と手取りは作った数で、本当の値段ではない
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { ExpectedFailure } = require("./expected-failure.js");
const { computeAppStoreMonthlyNumbers } = require("./finance");

// Subscription Report（1_3）の列。数字に使わない列も、本物と同じく並べる
const SUBSCRIPTION_COLUMNS = [
  "App Name",
  "App Apple ID",
  "Subscription Name",
  "Subscription Apple ID",
  "Subscription Group ID",
  "Standard Subscription Duration",
  "Subscription Offer Name",
  "Promotional Offer ID",
  "Customer Price",
  "Customer Currency",
  "Developer Proceeds",
  "Proceeds Currency",
  "Preserved Pricing",
  "Proceeds Reason",
  "Client",
  "Device",
  "State",
  "Country",
  "Active Standard Price Subscriptions",
  "Active Free Trial Introductory Offer Subscriptions",
  "Billing Retry",
  "Grace Period",
  "Subscribers",
];

// Subscription Event Report（1_3）の列
const SUBSCRIPTION_EVENT_COLUMNS = [
  "Event Date",
  "Event",
  "App Name",
  "App Apple ID",
  "Subscription Name",
  "Subscription Apple ID",
  "Subscription Group ID",
  "Standard Subscription Duration",
  "Device",
  "Client",
  "State",
  "Country",
  "Days Before Canceling",
  "Cancellation Reason",
  "Days Canceled",
  "Quantity",
];

// Summary Sales Report（1_0）の列
const SALES_COLUMNS = [
  "Provider",
  "Provider Country",
  "SKU",
  "Developer",
  "Title",
  "Version",
  "Product Type Identifier",
  "Units",
  "Developer Proceeds",
  "Begin Date",
  "End Date",
  "Customer Currency",
  "Country Code",
  "Currency of Proceeds",
  "Apple Identifier",
  "Customer Price",
  "Promo Code",
  "Parent Identifier",
  "Subscription",
  "Period",
  "Category",
  "CMB",
  "Device",
  "Supported Platforms",
  "Proceeds Reason",
  "Preserved Pricing",
  "Client",
  "Order Type",
];

// 列の名前で値を渡し、渡さなかった列は空にする。Apple の TSV と同じく、終わりに改行を付ける
const tsv = (columns, rows) =>
  `${[columns, ...rows.map((row) => columns.map((column) => String(row[column] ?? "")))].map((cells) => cells.join("\t")).join("\n")}\n`;

const subscriptionRow = (overrides) => ({
  "App Name": "nu-tori",
  "Customer Currency": "JPY",
  "Proceeds Currency": "JPY",
  Country: "JP",
  "Active Standard Price Subscriptions": 0,
  ...overrides,
});

const monthly = { "Subscription Name": "月額", "Standard Subscription Duration": "1 Month", "Customer Price": 1000 };
const yearly = { "Subscription Name": "年額", "Standard Subscription Duration": "1 Year", "Customer Price": 12000 };

const eventRow = (overrides) => ({ "App Name": "nu-tori", Country: "JP", ...overrides });

const salesRow = (overrides) => ({
  Title: "nu-tori",
  "Product Type Identifier": "IAY",
  "Customer Currency": "JPY",
  "Currency of Proceeds": "JPY",
  "Country Code": "JP",
  ...overrides,
});

// サブスクリプションのレポートがまだ作られていないときに Apple が返す 400 を、scripts/app-store-connect が止まるときの文の形にしたもの
const INVALID_VENDOR_NUMBER =
  '400 {"errors":[{"status":"400","code":"PARAMETER_ERROR.INVALID","detail":"Invalid vendor number specified"}]}';

// レポートの種類と日ごとの TSV を持ち、無い日は Apple の 404 と同じく null を返す
const readReportFrom = (reports) => async (reportType, date) => reports[reportType]?.[date] ?? null;

describe("App Store Connect の販売レポートから月のサブスクリプションの数字を出す", () => {
  describe("月額と年額の人がいて、月の中で入った人と解約した人と返金があるとき", () => {
    let numbers;
    before(async () => {
      const readReport = readReportFrom({
        SUBSCRIPTION: {
          "2026-02-01": tsv(SUBSCRIPTION_COLUMNS, [
            subscriptionRow({ ...monthly, "Active Standard Price Subscriptions": 4 }),
            subscriptionRow({ ...yearly, "Active Standard Price Subscriptions": 2 }),
          ]),
          "2026-02-28": tsv(SUBSCRIPTION_COLUMNS, [
            subscriptionRow({ ...monthly, "Active Standard Price Subscriptions": 5 }),
            subscriptionRow({ ...yearly, "Active Standard Price Subscriptions": 3 }),
            // 無料体験の人は有料で有効な数に入らない
            subscriptionRow({ ...monthly, "Active Free Trial Introductory Offer Subscriptions": 7 }),
          ]),
        },
        SUBSCRIPTION_EVENT: {
          "2026-02-10": tsv(SUBSCRIPTION_EVENT_COLUMNS, [
            eventRow({ ...monthly, "Event Date": "2026-02-10", Event: "Subscribe", Quantity: 2 }),
            eventRow({ ...monthly, "Event Date": "2026-02-10", Event: "Cancel", Quantity: 1 }),
          ]),
          "2026-02-20": tsv(SUBSCRIPTION_EVENT_COLUMNS, [
            eventRow({ ...yearly, "Event Date": "2026-02-20", Event: "Subscribe", Quantity: 1 }),
            eventRow({ ...monthly, "Event Date": "2026-02-20", Event: "Canceled from Billing Retry", Quantity: 1 }),
            eventRow({ ...monthly, "Event Date": "2026-02-20", Event: "Renew", Quantity: 3 }),
          ]),
        },
        SALES: {
          "2026-02-10": tsv(SALES_COLUMNS, [salesRow({ Units: 2, "Developer Proceeds": 700 })]),
          "2026-02-20": tsv(SALES_COLUMNS, [
            salesRow({ Units: 1, "Developer Proceeds": 8400 }),
            // 返金は Units が負になる
            salesRow({ Units: -1, "Developer Proceeds": 700 }),
          ]),
        },
      });
      numbers = await computeAppStoreMonthlyNumbers({ month: "2026-02", readReport });
    });

    it("月末の日の有料で有効な数を、月額と年額に分けて出すこと", () => {
      assert.deepEqual(numbers.subscribersByDuration, { "1 Month": 5, "1 Year": 3 });
    });

    it("MRR を、月末の日の有料で有効な数と値段から、年額を12で割って出すこと", () => {
      assert.equal(numbers.mrrJpy, 8000);
    });

    it("手取りを、その月の毎日の Units × Developer Proceeds の合計として出すこと", () => {
      assert.equal(numbers.proceedsJpy, 9100);
    });

    it("新しく入った人数を、その月の Subscribe の出来事の合計として出すこと", () => {
      assert.equal(numbers.newSubscribers, 3);
    });

    it("解約率の元の数として、その月の解約の出来事の合計と、月初めの日の有料で有効な数を出すこと", () => {
      assert.deepEqual(
        { cancellations: numbers.cancellations, activeAtStart: numbers.activeAtStart },
        { cancellations: 2, activeAtStart: 6 },
      );
    });

    it("読んだ日のうちレポートが無かった日を、レポートの種類ごとに挙げること", () => {
      // Subscription Report は月初めと月末の日だけを読む
      assert.deepEqual(
        {
          subscription: numbers.daysWithoutReport.subscription.length,
          subscriptionEvent: numbers.daysWithoutReport.subscriptionEvent.length,
          sales: numbers.daysWithoutReport.sales.length,
          firstDay: numbers.daysWithoutReport.sales.includes("2026-02-01"),
        },
        { subscription: 0, subscriptionEvent: 26, sales: 26, firstDay: true },
      );
    });
  });

  describe("期間が小文字で書かれているとき", () => {
    let numbers;
    before(async () => {
      // Apple の文書は「1 Month」、見本は「1 month」と書く
      const readReport = readReportFrom({
        SUBSCRIPTION: {
          "2026-02-28": tsv(SUBSCRIPTION_COLUMNS, [
            subscriptionRow({ ...monthly, "Standard Subscription Duration": "1 month", "Active Standard Price Subscriptions": 2 }),
            subscriptionRow({ ...yearly, "Standard Subscription Duration": "1 year", "Active Standard Price Subscriptions": 1 }),
          ]),
        },
      });
      numbers = await computeAppStoreMonthlyNumbers({ month: "2026-02", readReport });
    });

    it("期間を文書の書き方にそろえて人数を出すこと", () => {
      assert.deepEqual(numbers.subscribersByDuration, { "1 Month": 2, "1 Year": 1 });
    });
  });

  describe("円でない値段の行があるとき", () => {
    let readReport;
    before(() => {
      readReport = readReportFrom({
        SUBSCRIPTION: {
          "2026-02-28": tsv(SUBSCRIPTION_COLUMNS, [
            subscriptionRow({ ...monthly, "Customer Currency": "USD", "Active Standard Price Subscriptions": 1 }),
          ]),
        },
      });
    });

    it("MRR を出さずに止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /円でない値段/);
    });
  });

  describe("円でない手取りの行があるとき", () => {
    let readReport;
    before(() => {
      readReport = readReportFrom({
        SALES: {
          "2026-02-10": tsv(SALES_COLUMNS, [salesRow({ Units: 1, "Developer Proceeds": 5, "Currency of Proceeds": "USD" })]),
        },
      });
    });

    it("足さずに止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /円でない/);
    });
  });

  describe("知らない期間のサブスクリプションがあるとき", () => {
    let readReport;
    before(() => {
      readReport = readReportFrom({
        SUBSCRIPTION: {
          "2026-02-28": tsv(SUBSCRIPTION_COLUMNS, [
            subscriptionRow({
              "Standard Subscription Duration": "2 Weeks",
              "Customer Price": 500,
              "Active Standard Price Subscriptions": 1,
            }),
          ]),
        },
      });
    });

    it("MRR を出さずに止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /知らない期間/);
    });
  });

  describe("数でない値があるとき", () => {
    let readReport;
    before(() => {
      readReport = readReportFrom({
        SUBSCRIPTION_EVENT: {
          "2026-02-10": tsv(SUBSCRIPTION_EVENT_COLUMNS, [
            eventRow({ ...monthly, "Event Date": "2026-02-10", Event: "Subscribe", Quantity: "" }),
          ]),
        },
      });
    });

    it("0 として足さずに止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /数でない/);
    });
  });

  describe("数字に使う列が無いとき", () => {
    let readReport;
    before(() => {
      readReport = readReportFrom({
        SALES: { "2026-02-10": "Provider\tTitle\nAPPLE\tnu-tori\n" },
      });
    });

    it("列の形が変わったとみて止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /列が無い/);
    });
  });
  describe("サブスクリプションのレポートがまだ作られておらず、Summary Sales Report は読めるとき", () => {
    let numbers;
    before(async () => {
      const sales = readReportFrom({
        SALES: { "2026-02-10": tsv(SALES_COLUMNS, [salesRow({ Units: 1, "Developer Proceeds": 700 })]) },
      });
      const readReport = async (reportType, date) => {
        if (reportType === "SALES") return sales(reportType, date);
        throw new ExpectedFailure(INVALID_VENDOR_NUMBER);
      };
      numbers = await computeAppStoreMonthlyNumbers({ month: "2026-02", readReport });
    });

    it("止まらずに、サブスクリプションの数を 0 として出すこと", () => {
      assert.deepEqual(
        {
          subscribersByDuration: numbers.subscribersByDuration,
          mrrJpy: numbers.mrrJpy,
          newSubscribers: numbers.newSubscribers,
          activeAtStart: numbers.activeAtStart,
          proceedsJpy: numbers.proceedsJpy,
        },
        { subscribersByDuration: {}, mrrJpy: 0, newSubscribers: 0, activeAtStart: 0, proceedsJpy: 700 },
      );
    });

    it("まだ作られていなかった日を、レポートの種類ごとに挙げ、レポートが無い日には数えないこと", () => {
      assert.deepEqual(
        {
          subscription: numbers.daysReportNotCreated.subscription,
          subscriptionEvent: numbers.daysReportNotCreated.subscriptionEvent.length,
          subscriptionWithoutReport: numbers.daysWithoutReport.subscription.length,
        },
        { subscription: ["2026-02-01", "2026-02-28"], subscriptionEvent: 28, subscriptionWithoutReport: 0 },
      );
    });
  });

  describe("月の途中からサブスクリプションのレポートが作られたとき", () => {
    let numbers;
    before(async () => {
      const reports = readReportFrom({
        SUBSCRIPTION_EVENT: {
          "2026-02-20": tsv(SUBSCRIPTION_EVENT_COLUMNS, [
            eventRow({ ...monthly, "Event Date": "2026-02-20", Event: "Subscribe", Quantity: 1 }),
          ]),
        },
      });
      const readReport = async (reportType, date) => {
        if (reportType !== "SALES" && date < "2026-02-20") throw new ExpectedFailure(INVALID_VENDOR_NUMBER);
        return reports(reportType, date);
      };
      numbers = await computeAppStoreMonthlyNumbers({ month: "2026-02", readReport });
    });

    it("作られたあとの日の出来事を数えること", () => {
      assert.equal(numbers.newSubscribers, 1);
    });

    it("作られる前の日だけを、まだ作られていなかった日に挙げること", () => {
      assert.equal(numbers.daysReportNotCreated.subscriptionEvent.at(-1), "2026-02-19");
    });
  });

  describe("Summary Sales Report も同じ 400 を返すとき", () => {
    let readReport;
    before(() => {
      readReport = async () => {
        throw new ExpectedFailure(INVALID_VENDOR_NUMBER);
      };
    });

    it("番号が違うとみて止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /Invalid vendor number/);
    });
  });

  describe("サブスクリプションのレポートが別の内容の 400 を返すとき", () => {
    let readReport;
    before(() => {
      readReport = async (reportType) => {
        if (reportType === "SALES") return null;
        throw new ExpectedFailure('400 {"errors":[{"detail":"Invalid date"}]}');
      };
    });

    it("止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), /Invalid date/);
    });
  });

  describe("サブスクリプションのレポートが 400 でない状態で同じ文を返すとき", () => {
    let readReport;
    before(() => {
      readReport = async (reportType) => {
        if (reportType === "SALES") return null;
        throw new ExpectedFailure("401 Invalid vendor number specified");
      };
    });

    it("止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), { message: /^401 / });
    });
  });

  describe("サブスクリプションのレポートが ExpectedFailure でない誤りで同じ文を返すとき", () => {
    let readReport;
    before(() => {
      readReport = async (reportType) => {
        if (reportType === "SALES") return null;
        throw new Error("400 Invalid vendor number specified");
      };
    });

    it("止まること", async () => {
      await assert.rejects(computeAppStoreMonthlyNumbers({ month: "2026-02", readReport }), { message: /^400 Invalid vendor/ });
    });
  });
});
