extension SyncWrite {
    /// 書き込みが当たる記録の種類。全部の case を並べる switch はここ1か所にする。case を足したら、ここに種類を書く。
    /// 種類の適合（`RecordKindWriteWireCoding`）は、自分の case を `if case` で取り出す
    var recordKind: Components.Schemas.RecordKindName {
        switch self {
        case .createWeightRecord, .updateWeightRecord, .sourceDeletedWeightRecord: .weightRecord
        case .updateAccountSettings: .accountSettings
        case .createMeal, .updateMeal, .deleteMeal: .meal
        case .createDish, .deleteDish, .updateDish: .dish
        case .updateIngredient: .ingredient
        case .createNotice, .respondNotice: .notice
        case .createSentText, .resendSentTextAsConversation, .resendSentText: .sentText
        }
    }

    /// 送る書き込みの線上の形を、種類の符号化の表から引く
    func wire() throws -> Wire {
        guard let wire = RecordKindWireCodings.coding(of: recordKind)?.writes?.wire(of: self) else {
            throw MissingWireCodingError(kind: recordKind.rawValue)
        }
        return wire
    }

    /// `recordKind` の種類の適合に、この書き込みの case を足し忘れている
    struct MissingWireCodingError: Error {
        let kind: String
    }
}
