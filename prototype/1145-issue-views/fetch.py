"""試作用。開いている Issue と、その親子・依存・版を読み、index.html のデータを書き換える。

使い方: python3 prototype/1145-issue-views/fetch.py [--active <Issue の番号> ...]

--active には、動いているセッションが結びついた Issue の番号を渡す。セッションの一覧は GitHub からは読めず、
Claude のセッションが list_sessions で読んで、名前の先頭の「#<番号>」で結びつける（.agents/skills/dispatch/SKILL.md）。
"""

import datetime
import json
import pathlib
import re
import subprocess
import sys

R = "repos/gn-t-k/nu-tori"
HERE = pathlib.Path(__file__).parent


def api(path):
    out = subprocess.run(["gh", "api", "--paginate", "--slurp", path], capture_output=True, text=True)
    if out.returncode:
        raise SystemExit(out.stderr)
    return [x for page in json.loads(out.stdout) for x in page]


def slim(i):
    return {
        "n": i["number"],
        "title": i["title"],
        "state": i["state"],
        "labels": [l["name"] for l in i["labels"]],
        "milestone": i["milestone"]["title"] if i["milestone"] else None,
        "closed": (i.get("closed_at") or "")[:10] or None,
        "pr": "pull_request" in i,
        "subs_total": (i.get("sub_issues_summary") or {}).get("total", 0),
        "subs_done": (i.get("sub_issues_summary") or {}).get("completed", 0),
        "blocked_by_open": (i.get("issue_dependencies_summary") or {}).get("blocked_by", 0),
    }


today = datetime.date.today()
issues = {i["number"]: slim(i) for i in api(f"{R}/issues?state=open&per_page=100")}
# 版に入っているものは、閉じたものも読む
for m in api(f"{R}/milestones?state=all"):
    for i in api(f"{R}/issues?state=all&milestone={m['number']}&per_page=100"):
        issues.setdefault(i["number"], slim(i))
# この2週間に閉じたもの
since = (today - datetime.timedelta(days=14)).isoformat()
for i in api(f"{R}/issues?state=closed&since={since}T00:00:00Z&per_page=100"):
    if "pull_request" not in i and i["closed_at"][:10] >= since:
        issues.setdefault(i["number"], slim(i))

for n in [n for n, i in issues.items() if i["subs_total"] and not i["pr"]]:
    for s in api(f"{R}/issues/{n}/sub_issues?per_page=100"):
        issues.setdefault(s["number"], slim(s))
        issues[s["number"]]["parent"] = n
for n in [n for n, i in issues.items() if i["blocked_by_open"] and i["state"] == "open"]:
    deps = api(f"{R}/issues/{n}/dependencies/blocked_by?per_page=100")
    issues[n]["blocked_by"] = [d["number"] for d in deps if d["state"] == "open"]

# 開いている PR と、その PR が閉じる Issue
out = subprocess.run(
    ["gh", "api", "graphql", "-f", "query={repository(owner:\"gn-t-k\",name:\"nu-tori\"){pullRequests(states:OPEN,first:50)"
     "{nodes{number title isDraft closingIssuesReferences(first:5){nodes{number}}}}}}"],
    capture_output=True, text=True, check=True,
)
prs = [
    {"n": p["number"], "title": p["title"], "draft": p["isDraft"], "closes": [c["number"] for c in p["closingIssuesReferences"]["nodes"]]}
    for p in json.loads(out.stdout)["data"]["repository"]["pullRequests"]["nodes"]
]
active = [int(n) for n in sys.argv[sys.argv.index("--active") + 1:]] if "--active" in sys.argv else []

data = {"fetched": today.isoformat(), "active": active, "prs": prs, "issues": sorted(issues.values(), key=lambda i: i["n"])}
page = HERE / "index.html"
page.write_text(
    re.sub(
        r"/\*DATA\*/.*?/\*END\*/",
        lambda _: "/*DATA*/" + json.dumps(data, ensure_ascii=False).replace("</", "<\\/") + "/*END*/",
        page.read_text(),
        flags=re.S,
    )
)
print(len(issues), "件")
