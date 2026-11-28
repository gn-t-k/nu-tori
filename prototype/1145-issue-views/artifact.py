"""index.html から、Artifact に載せる形（<html>・<head>・<body> の枠を外したもの）を書き出す。

使い方: python3 prototype/1145-issue-views/artifact.py <書き出す先>
載せ先のリンクは #1145 のコメントにある。直したら同じページに載せ直す。
"""

import pathlib
import re
import sys

page = (pathlib.Path(__file__).parent / "index.html").read_text()
page = re.sub(r"<!doctype html>|</?html[^>]*>|</?head>|</?body>|<meta charset[^>]*>|<meta name=\"viewport\"[^>]*>", "", page)
pathlib.Path(sys.argv[1]).write_text(page.lstrip())
