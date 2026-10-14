#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    extension UITestLaunch {
        /// 偽の同期サーバーの場面。初めに置く記録と方針だけで書く。記録の日付と時刻は、アプリと同じ止めた時計で決める
        func syncScenario() -> FakeSyncServer.Scenario {
            let today = TimelineDayText.startedOn(for: clock.today())
            if account == .signedInFetching {
                return .init(records: [], startedOn: today, pull: .hangs)
            }
            switch api {
            case .online:
                return .init(records: [], startedOn: today)
            case .offline:
                return .init(records: [], startedOn: today, connection: .offline)
            case .appBuildUnsupported:
                return .init(records: [], startedOn: today, connection: .appBuildUnsupported)
            case .weightRecords:
                return .init(
                    records: [
                        todaysManualWeight,
                        tomorrowsImportedWeight,
                    ],
                    startedOn: today)
            case .previousDay:
                return previousDay(writePolicies: [:])
            case .previousDayPushOffline:
                return previousDay(writePolicies: [
                    RecordKindName.weightRecord.serverName: .unreachable
                ])
            case .previousDayPushRejected:
                // サーバーにその記録は無い（作る書き込みが受け付けられなかった）
                return previousDay(writePolicies: [RecordKindName.weightRecord.serverName: .reject])
            case .weightScreen:
                return .init(
                    records: [
                        todaysManualWeight
                    ],
                    startedOn: today)
            case .weightScreenPushRejected:
                // 直す書き込みを受け付けず、サーバーの今の値（直す前の記録）を添える
                return .init(
                    records: [
                        todaysManualWeight
                    ],
                    startedOn: today,
                    writePolicies: [RecordKindName.weightRecord.serverName: .reject])
            case .dayRing:
                return dayRing()
            case .unevenDays:
                return unevenDays()
            case .mealEstimation:
                return .init(
                    records: [], startedOn: today, estimatedDishes: Self.oyakodon(mealId:))
            case .mealEdit:
                // 推定中の食事の画面を開いて見られるよう、推定を、推定中を返してから3回あとの取得まで終えない。取りに行くのは3秒おき（`EstimationFollowUpTests`）だが、写真を送り終えたあとの取得がアプリのターゲットから挟まるので、この 3 が何秒あとになるかを確かめる NuToriCore の単体テストは無い。シミュレーターでは、写真を選んでから6秒ほどあと
                return .init(
                    records: [], startedOn: today, estimatedDishes: Self.oyakodon(mealId:),
                    estimateDish: Self.reestimate(dishId:name:), mealEstimationPulls: 3)
            case .conversation:
                // 読んでいますを、画面の読み取りが遅い CI でも見られるよう、答えるのを5回めの取得まで待つ。5 は、NuToriCore の `RecordSyncTests` の「文章を送ったあと」の `RepliedAtFifthPull` が確かめる取得の並び（送ってすぐ、見守る要求が閉じてすぐ、そのあと3秒おきの [0, 0, 3, 6, 9] 秒）に合わせた数で、答えは送ってから9秒あとに届く。食事と読み分ける文章は、同じ5回めに読み分けが届き、その次の取得（3秒あと）で推定を終える（同じ並びを `ClassifiedAsMealAtThirdPull` が確かめる）。段取りの並びを変えたら、この数も数え直す
                return .init(
                    records: [], startedOn: today, estimatedDishes: Self.oyakodon(mealId:),
                    answerSentText: Self.answer(sentText:), sentTextAnswerPulls: 5)
            case .goalSetup:
                return .init(
                    records: [todaysManualWeight], startedOn: today,
                    goalSetup: goalSetupAnswers(today: today))
            case .accountDeletionRateLimited:
                return .init(records: [], startedOn: today, accountDeletion: .rateLimited)
            case .accountDeletionUnauthorized:
                return .init(records: [], startedOn: today, accountDeletion: .sessionExpired)
            }
        }

        private static let manualId = fixedId("11111111-1111-4111-8111-111111111111")
        private static let importedId = fixedId("22222222-2222-4222-8222-222222222222")
        private static let withings = SyncedWeightRecord.Imported(
            sourceAppName: "Withings", sourceBundleId: "com.withings.wiScaleNG",
            healthKitSampleId: fixedId("33333333-3333-4333-8333-333333333333"), bodyFat: nil)

        /// 昨日の体重だけを置き、今日は未記録にする
        private func previousDay(
            writePolicies: [String: FakeSyncServer.WritePolicy]
        ) -> FakeSyncServer.Scenario {
            .init(
                records: [
                    weight(
                        Self.fixedId("44444444-4444-4444-8444-444444444444"), 72.6,
                        dayOffset: -1, hour: 7, minute: 12, imported: nil)
                ],
                startedOn: TimelineDayText.startedOn(for: clock.today().advanced(by: -1)),
                writePolicies: writePolicies)
        }

        /// 使い始めた日を3週間前にし、その日に記録を2件置く。帯を週単位で送って、画面の外の日へ移れる。
        /// 使い始めた次の日を除く間の日にも2件ずつ置き、開いたときに並べる分（`TimelineViewport` の、項目30個）に使い始めた日が入らないようにする
        private func dayRing() -> FakeSyncServer.Scenario {
            let between = (-19 ... -1).enumerated().flatMap { index, dayOffset in
                [
                    weight(
                        Self.fixedId(String(format: "bbbbbbbb-bbbb-4bbb-8bbb-%012d", index)), 71.0,
                        dayOffset: dayOffset, hour: 7, minute: 0, imported: nil),
                    weight(
                        Self.fixedId(String(format: "bbbbbbbb-bbbb-4bbb-9bbb-%012d", index)), 71.2,
                        dayOffset: dayOffset, hour: 21, minute: 0, imported: nil),
                ]
            }
            return .init(
                records: [
                    weight(
                        Self.fixedId("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"), 70.0, dayOffset: -21,
                        hour: 6, minute: 0, imported: nil),
                    weight(
                        Self.fixedId("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"), 70.5, dayOffset: -21,
                        hour: 21, minute: 0, imported: nil),
                    todaysManualWeight,
                    tomorrowsImportedWeight,
                ] + between,
                startedOn: TimelineDayText.startedOn(for: clock.today().advanced(by: -21)))
        }

        /// 逆算できる人の初めての目標。開始の日は今日、体重の傾向は 72.0 kg、推定消費カロリーは 2,250 kcal。
        /// 案の値は期限によらず同じにする（計算はサーバーのテストで確かめる）
        private func goalSetupAnswers(today: String) -> FakeSyncServer.GoalSetupAnswers {
            let clock = clock
            return FakeSyncServer.GoalSetupAnswers(
                preview: GoalSetupPreview(canBackCalculate: true, canOfferLoseProposals: true),
                proposals: { plan in Self.goalProposals(plan, today: today) },
                assessCustomTargetWeight: { _, kilograms in
                    // 体重の傾向から離れるほど、1日の目安を推定消費カロリーから離す
                    let difference = Int(((72.0 - kilograms).magnitude * 140 / 50).rounded()) * 50
                    let energy = kilograms < 72.0 ? 2250 - difference : 2250 + difference
                    return .accepted(
                        .init(
                            dailyGuide: Self.dailyGuide(energy),
                            difficulty: difference > 400
                                ? .hard : difference > 200 ? .standard : .gentle,
                            dailyGuideDifferenceKilocalories: energy - 2250))
                },
                now: { clock.now() })
        }

        nonisolated private static func goalProposals(
            _ requested: GoalProposalsPlan, today: String
        ) -> GoalProposals {
            let plan: GoalProposals.Plan
            switch requested {
            case .weightChange(.lose, let deadlineOn):
                plan = .weightChange(
                    .init(
                        direction: .lose, deadlineOn: deadlineOn,
                        proposals: [
                            offered(.gentle, 70.6, 2050), offered(.standard, 69.2, 1850),
                            offered(.hard, 67.8, 1650),
                        ],
                        acceptedTargetWeightRange: .init(
                            minimumKilograms: 67.8, maximumKilograms: 71.9,
                            fastestEndReason: .paceTooFast)))
            case .weightChange(.gain, let deadlineOn):
                plan = .weightChange(
                    .init(
                        direction: .gain, deadlineOn: deadlineOn,
                        proposals: [
                            offered(.gentle, 72.8, 2350), offered(.standard, 73.7, 2450),
                            offered(.hard, 74.9, 2600),
                        ],
                        acceptedTargetWeightRange: .init(
                            minimumKilograms: 72.1, maximumKilograms: 74.9,
                            fastestEndReason: .paceTooFast)))
            case .maintain:
                plan = .maintenance(
                    .init(targetWeightKilograms: 72.0, dailyGuide: dailyGuide(2250)))
            }
            return GoalProposals(
                startedOn: today, expenditureKilocalories: 2250, expenditureSource: .backCalculated,
                startingWeightTrendKilograms: 72.0, lastWeightRecordedOn: today, plan: plan)
        }

        nonisolated private static func offered(
            _ pace: GoalProposals.Pace, _ kilograms: Double, _ energy: Int
        ) -> GoalProposals.Proposal {
            .init(
                pace: pace,
                availability: .offered(
                    .init(
                        pace: pace, targetWeightKilograms: kilograms,
                        dailyGuide: dailyGuide(energy),
                        difficulty: pace, dailyGuideDifferenceKilocalories: energy - 2250)))
        }

        /// P・F・C は kcal によらず同じにする
        nonisolated private static func dailyGuide(_ energy: Int) -> DailyGuidePlan {
            DailyGuidePlan(
                energyKilocalories: energy, proteinGrams: 115, fatGrams: 50, carbohydrateGrams: 200)
        }

        /// 高さのばらつく日を並べる。おとといは短い返事、昨日は画面の数倍ある返事、今日は体重だけ。
        /// まだ描いていない日の高さの見積もりが、実際の高さから大きく外れる
        private func unevenDays() -> FakeSyncServer.Scenario {
            let shortTalk = talk(
                sentTextId: Self.fixedId("cccccccc-cccc-4ccc-8ccc-ccccccccccc1"),
                replyId: Self.fixedId("dddddddd-dddd-4ddd-8ddd-ddddddddddd1"),
                dayOffset: -2, replyParagraphs: 3)
            let longTalk = talk(
                sentTextId: Self.fixedId("cccccccc-cccc-4ccc-8ccc-ccccccccccc2"),
                replyId: Self.fixedId("dddddddd-dddd-4ddd-8ddd-ddddddddddd2"),
                dayOffset: -1, replyParagraphs: 30)
            return .init(
                records: shortTalk + longTalk + [
                    weight(
                        Self.fixedId("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1"), 71.0, dayOffset: 0,
                        hour: 6, minute: 0, imported: nil)
                ],
                startedOn: TimelineDayText.startedOn(for: clock.today().advanced(by: -2)))
        }

        /// 12:00 に送ったプリセットの文章と、その返事。返事は、同じ段落を replyParagraphs 回くり返す
        private func talk(
            sentTextId: UUID, replyId: UUID, dayOffset: Int, replyParagraphs: Int
        ) -> [SyncChange] {
            [
                .sentText(
                    SyncedSentText(
                        id: sentTextId, body: TextPreset.mealFeedbackSoFar.text,
                        sentAt: date(dayOffset: dayOffset, hour: 12, minute: 0),
                        timeZone: clock.timeZone())),
                .sentTextStatus(
                    SyncedSentTextStatus(
                        sentTextId: sentTextId, classification: .conversation, reply: .replied)),
                .aiUtterance(
                    SyncedAiUtterance(
                        id: replyId,
                        body: String(
                            repeating: "今日は朝ごはんから **たんぱく質** がとれています。\n- 昼は野菜を足す\n- 夜は軽めに\n\n",
                            count: replyParagraphs),
                        sentTextId: sentTextId, mealIds: [])),
            ]
        }

        /// 今日 7:12 に手で記録した 72.4 kg
        private var todaysManualWeight: SyncChange {
            weight(Self.manualId, 72.4, dayOffset: 0, hour: 7, minute: 12, imported: nil)
        }

        /// 明日 8:00 に Withings から取り込んだ 71.8 kg
        private var tomorrowsImportedWeight: SyncChange {
            weight(
                Self.importedId, 71.8, dayOffset: 1, hour: 8, minute: 0, imported: Self.withings)
        }

        private func weight(
            _ id: UUID, _ kilograms: Double, dayOffset: Int, hour: Int, minute: Int,
            imported: SyncedWeightRecord.Imported?
        ) -> SyncChange {
            .weightRecord(
                SyncedWeightRecord(
                    id: id, weightKilograms: kilograms,
                    measuredAt: date(dayOffset: dayOffset, hour: hour, minute: minute),
                    timeZone: clock.timeZone(), version: 1, imported: imported))
        }

        private func date(dayOffset: Int, hour: Int, minute: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = clock.timeZone()
            let start = calendar.startOfDay(for: clock.now())
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
                let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else {
                preconditionFailure("止めた時計から \(dayOffset) 日後の \(hour):\(minute) を作れない")
            }
            return date
        }

        /// 親子丼（鶏もも肉 80 g・ご飯 200 g。どちらも成分表）。料理と材料の ID は、推定を終えたときに振る
        nonisolated private static func oyakodon(mealId: UUID) -> [SyncChange] {
            let dishId = UUID()
            return [
                .dish(
                    SyncedDish(
                        id: dishId, mealId: mealId, name: "親子丼",
                        quantity: .init(value: 1, unit: "杯", source: .estimated),
                        positionInMeal: 0, version: 1)),
                .ingredient(
                    SyncedIngredient(
                        id: UUID(), dishId: dishId, name: "鶏もも肉", quantity: 80,
                        quantitySource: .estimated, unit: "g",
                        edibleGramsPerUnit: 1, positionInDish: 0,
                        nutrientSource: .foodComposition(foodNumber: "11221"),
                        nutrients: [
                            "energy_kcal": 190, "protein_g": 16.6, "fat_g": 14.2,
                            "carbohydrate_g": 0,
                        ])),
                .ingredient(
                    SyncedIngredient(
                        id: UUID(), dishId: dishId, name: "ご飯", quantity: 200,
                        quantitySource: .estimated, unit: "g",
                        edibleGramsPerUnit: 1, positionInDish: 1,
                        nutrientSource: .foodComposition(foodNumber: "01088"),
                        nutrients: [
                            "energy_kcal": 156, "protein_g": 2.5, "fat_g": 0.3,
                            "carbohydrate_g": 37.1,
                        ])),
            ]
        }

        /// 送った文章の本文ごとの答え方。プリセットは会話、「昼は親子丼」は食事、「次の食事は？」は1回めは作れない
        nonisolated private static func answer(sentText body: String) -> FakeSyncServer
            .SentTextAnswer?
        {
            switch body {
            case TextPreset.mealFeedbackSoFar.text:
                .reply("今日は朝ごはんから **たんぱく質** がとれています。\n- 昼は野菜を足す\n- 夜は軽めに")
            case "昼は親子丼":
                .meal(replyAsConversation: "親子丼の話ですね。卵と鶏肉でたんぱく質がとれます。")
            case "次の食事は？":
                .failsThenReply("野菜の多い定食はどうでしょう。")
            default:
                nil
            }
        }

        /// 推定し直しで、名前から作る量と材料。カツ丼（豚ロース 100 g・ご飯 200 g）と味噌汁（味噌 18 g）のほかは、材料を推定できない
        nonisolated private static func reestimate(dishId: UUID, name: String)
            -> FakeSyncServer.DishEstimate?
        {
            switch name {
            case "カツ丼":
                FakeSyncServer.DishEstimate(
                    quantity: .init(value: 1, unit: "杯", source: .estimated),
                    ingredients: [
                        ingredient(
                            dishId: dishId, name: "豚ロース", grams: 100, position: 0,
                            foodNumber: "11123",
                            nutrients: [
                                "energy_kcal": 248, "protein_g": 19.3, "fat_g": 19.2,
                                "carbohydrate_g": 0.2,
                            ]),
                        ingredient(
                            dishId: dishId, name: "ご飯", grams: 200, position: 1,
                            foodNumber: "01088",
                            nutrients: [
                                "energy_kcal": 156, "protein_g": 2.5, "fat_g": 0.3,
                                "carbohydrate_g": 37.1,
                            ]),
                    ])
            case "味噌汁":
                FakeSyncServer.DishEstimate(
                    quantity: .init(value: 1, unit: "杯", source: .estimated),
                    ingredients: [
                        ingredient(
                            dishId: dishId, name: "米みそ", grams: 18, position: 0,
                            foodNumber: "17045",
                            nutrients: [
                                "energy_kcal": 182, "protein_g": 12.5, "fat_g": 6.0,
                                "carbohydrate_g": 21.9,
                            ])
                    ])
            default:
                nil
            }
        }

        /// 成分表の材料。栄養の値は 100 g あたり。ID は推定し直しを終えたときに振る
        nonisolated private static func ingredient(
            dishId: UUID, name: String, grams: Double, position: Int, foodNumber: String,
            nutrients: [String: Double]
        ) -> SyncedIngredient {
            SyncedIngredient(
                id: UUID(), dishId: dishId, name: name, quantity: grams,
                quantitySource: .estimated, unit: "g", edibleGramsPerUnit: 1,
                positionInDish: position, nutrientSource: .foodComposition(foodNumber: foodNumber),
                nutrients: nutrients)
        }

        private static func fixedId(_ text: String) -> UUID {
            guard let id = UUID(uuidString: text) else {
                preconditionFailure("UUID の形でない \(text)")
            }
            return id
        }
    }
#endif
