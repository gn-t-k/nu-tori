"""PROTOTYPE: ヘルスケアの書き出し（zip）から、推定消費量の試作に使う日ごとの系列を取り出す。

使い方:
    python3 prototype/0001-expenditure/extract.py ~/repository/nu-tori/書き出したデータ.zip

同じフォルダに data.local.js を書く（.gitignore 済み。健康データなのでコミットしない）。
index.html は data.local.js があればそれを、なければ作り物の系列を使う。
"""
import collections, json, os, re, sys, zipfile

WANT = {
    "BodyMass": "wt", "BodyFatPercentage": "bf",
    "DietaryEnergyConsumed": "kcal", "DietaryProtein": "p",
    "DietaryFatTotal": "f", "DietaryCarbohydrates": "c",
}
attr = re.compile(r'(\w+)="([^"]*)"')

def main(zpath):
    me, height = {}, None
    # day -> source -> {kcal,p,f,c}
    food = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(float)))
    wt, bf = {}, {}
    with zipfile.ZipFile(zpath) as z, z.open("apple_health_export/export.xml") as fh:
        for raw in fh:
            # 食品の組（Correlation）の中の Record は、外側の Record と同じものの再掲なので数えない
            if raw.lstrip().startswith(b"<Me "):
                me = dict(attr.findall(raw.decode()))
                continue
            if not raw.startswith(b' <Record type="HKQuantityTypeIdentifier'):
                continue
            line = raw.decode()
            d = dict(attr.findall(line))
            t = d["type"][len("HKQuantityTypeIdentifier"):]
            if t == "Height":
                height = float(d["value"])
                continue
            if t not in WANT:
                continue
            day, v, src = d["startDate"][:10], float(d["value"]), d["sourceName"]
            k = WANT[t]
            if k == "wt":
                wt[day] = v
            elif k == "bf":
                bf[day] = v * 100 if v < 1 else v
            else:
                food[day][src][k] += v
    days = {}
    for day, bysrc in food.items():
        # 1日ごとに1つの出どころを選ぶ（二重計上を避ける）。一番多く書いた出どころを採る
        src, n = max(bysrc.items(), key=lambda kv: kv[1]["kcal"])
        days[day] = {"kcal": round(n["kcal"]), "p": round(n["p"]), "f": round(n["f"]), "c": round(n["c"]),
                     "src": src, "others": {s: round(x["kcal"]) for s, x in bysrc.items() if s != src}}
    for day, v in wt.items():
        days.setdefault(day, {})["wt"] = round(v, 2)
    for day, v in bf.items():
        days.setdefault(day, {})["bf"] = round(v, 1)
    out = {
        "label": "開発者のヘルスケアの書き出し",
        "profile": {
            "sex": "male" if me.get("HKCharacteristicTypeIdentifierBiologicalSex") == "HKBiologicalSexMale" else "female",
            "birth": me.get("HKCharacteristicTypeIdentifierDateOfBirth"),
            "height": height,
        },
        "days": dict(sorted(days.items())),
    }
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data.local.js")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("window.NUTORI_DATA = ")
        json.dump(out, fh, ensure_ascii=False)
        fh.write(";\n")
    print(f"wrote {path}: {len(days)} days")

if __name__ == "__main__":
    main(os.path.expanduser(sys.argv[1]))
