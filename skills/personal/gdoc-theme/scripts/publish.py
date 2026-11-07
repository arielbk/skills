#!/usr/bin/env python3
"""Publish a themed Google Doc from HTML.

Wraps body HTML in the house theme, imports it via Drive (HTML -> Google Doc),
then runs a fixup pass that the importer makes necessary:
  - the first heading becomes a real TITLE paragraph at 26pt (the importer
    renders it as another HEADING_1, so the doc would have no Title)
  - headings are pinned to Helvetica Neue as a safety net. Normally a no-op:
    the importer sets the document default font from the body rule and Docs
    normalises redundant run styling away.
  - paragraphs either side of a callout table get room to breathe. A Docs table
    has no margin, so the air around a callout has to live on its neighbours.
  - <code> runs get Roboto Mono. font-family is stripped on import but run-level
    background-color survives, so the CSS tint doubles as the marker.

Usage:
  publish.py --html body.html --title "Doc Name"          # create
  publish.py --html body.html --doc-id <id>               # replace content, same URL
  publish.py --doc-id <id>                                # restyle in place, content untouched

The last form re-runs the fixup against a live document without importing
anything, so hand edits made in Docs survive. Every fixup request is
idempotent, so it is safe to repeat.
"""
import argparse, json, os, pathlib, re, subprocess, sys, uuid

THEME = pathlib.Path(__file__).resolve().parent.parent / "assets" / "theme.css"

CODE_TINT = (0xF1 / 255, 0xF1 / 255, 0xF1 / 255)   # must match code tint in theme.css
MONO_FONT = "Roboto Mono"
RED = "#D82828"        # house accent
BLOCK_FILL = "#F4F9FF" # house light-blue block fill
CALLOUT_GAP = 16       # points of air above and below a callout table

# Heading space above/below in points. Pinned here rather than left to CSS:
# the importer folds a preceding <ul>'s or <blockquote>'s margin into the next
# element, so padding-top alone gives a heading after a list no space at all.
HEADING_SPACE = {"HEADING_1": (30, 10), "HEADING_2": (24, 8), "HEADING_3": (16, 6)}
STACKED_HEADING_ABOVE = 12  # a heading straight after another heading; they are one unit


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return {"color": {"rgbColor": {"red": int(h[0:2], 16) / 255,
                                   "green": int(h[2:4], 16) / 255,
                                   "blue": int(h[4:6], 16) / 255}}}


def pt(n):
    return {"magnitude": n, "unit": "PT"}


def is_code_run(el):
    """A run the CSS tinted with CODE_TINT. The tint survives import; the font does not."""
    c = (el.get("textRun", {}).get("textStyle", {})
           .get("backgroundColor", {}).get("color", {}).get("rgbColor"))
    if not c:
        return False
    got = (c.get("red", 0), c.get("green", 0), c.get("blue", 0))
    return all(abs(a - b) < 0.02 for a, b in zip(got, CODE_TINT))


def gws(*args, stdin_json=None):
    cmd = ["gws", *args]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit(f"gws failed: {' '.join(cmd)}\n{p.stderr}")
    body = "\n".join(l for l in p.stdout.splitlines() if not l.startswith("Using keyring"))
    start = body.find("{")
    if start < 0:
        sys.exit(f"no JSON in gws output:\n{p.stdout}")
    return json.loads(body[start:])


def wrap(fragment, title):
    # The importer applies CSS from a class on a <span> but ignores it on <code>,
    # so rewrite the natural authoring form into the one that survives.
    fragment = re.sub(r"<code>(.*?)</code>", r'<span class="mono">\1</span>',
                      fragment, flags=re.S)
    if "<body" in fragment.lower():
        return fragment
    css = THEME.read_text()
    return (f'<html><head><meta charset="utf-8"><title>{title}</title>'
            f"<style>{css}</style></head><body>{fragment}</body></html>")


def table_gaps(doc):
    """Space around and inside callout tables.

    Outside: a Docs table takes no margin of its own, so the air around a
    callout has to live on the paragraphs either side of it.

    Inside: the importer maps the cell's CSS padding onto BOTH the cell padding
    and the inner paragraph's spaceAbove/spaceBelow, so the padding lands twice.
    Docs then suppresses spaceAbove at the top of a cell but honours spaceBelow
    at the bottom, which is what makes an untreated callout bottom-heavy. Zero
    the inner paragraph spacing and let the cell padding do the work.
    """
    items = doc["body"]["content"]
    reqs = []
    for i, e in enumerate(items):
        if "table" not in e:
            continue
        for row in e["table"]["tableRows"]:
            for cell in row["tableCells"]:
                paras = [c for c in cell["content"] if "paragraph" in c]
                for k, c in enumerate(paras):
                    rng = {"startIndex": c["startIndex"], "endIndex": c["endIndex"] - 1}
                    if rng["endIndex"] <= rng["startIndex"]:
                        continue
                    reqs.append({"updateParagraphStyle": {
                        "range": rng, "fields": "spaceAbove,spaceBelow",
                        "paragraphStyle": {"spaceAbove": pt(0 if k == 0 else 10),
                                           "spaceBelow": pt(0)}}})
        for j, field in ((i - 1, "spaceBelow"), (i + 1, "spaceAbove")):
            if not 0 <= j < len(items):
                continue
            p = items[j].get("paragraph")
            if not p or p.get("paragraphStyle", {}).get("namedStyleType", "") != "NORMAL_TEXT":
                continue  # headings already carry their own pinned spacing
            rng = {"startIndex": items[j]["startIndex"], "endIndex": items[j]["endIndex"] - 1}
            if rng["endIndex"] <= rng["startIndex"]:
                continue
            reqs.append({"updateParagraphStyle": {
                "range": rng, "fields": field,
                "paragraphStyle": {field: pt(CALLOUT_GAP)}}})
    return reqs


def fixup(doc_id):
    """Everything the Drive HTML importer cannot express.

    No request here changes an index, so the whole batch is order-independent.
    """
    doc = gws("docs", "documents", "get", "--params", json.dumps({"documentId": doc_id}))
    style, first, prev_named = [], True, ""
    for e in doc["body"]["content"]:
        p = e.get("paragraph")
        if not p:
            continue
        elements = p.get("elements", [])
        text = "".join(el.get("textRun", {}).get("content", "") for el in elements)
        if not text.strip():
            continue
        rng = {"startIndex": e["startIndex"], "endIndex": e["endIndex"] - 1}
        if rng["endIndex"] <= rng["startIndex"]:
            continue
        named = p.get("paragraphStyle", {}).get("namedStyleType", "")

        if first:
            first = False
            style.append({"updateParagraphStyle": {
                "range": rng, "paragraphStyle": {"namedStyleType": "TITLE"},
                "fields": "namedStyleType"}})
            style.append({"updateTextStyle": {
                "range": rng, "fields": "weightedFontFamily,fontSize,bold",
                "textStyle": {"weightedFontFamily": {"fontFamily": "Helvetica Neue"},
                              "fontSize": pt(26), "bold": True}}})
        elif named.startswith("HEADING"):
            style.append({"updateTextStyle": {
                "range": rng, "fields": "weightedFontFamily",
                "textStyle": {"weightedFontFamily": {"fontFamily": "Helvetica Neue"}}}})
            above, below = HEADING_SPACE.get(named, (16, 6))
            if prev_named.startswith("HEADING") or prev_named == "TITLE":
                # A section heading sitting straight on top of its first
                # sub-heading reads as one block, not two. Full separation
                # there leaves the sub-heading floating loose from its section.
                above = STACKED_HEADING_ABOVE
            style.append({"updateParagraphStyle": {
                "range": rng, "fields": "spaceAbove,spaceBelow",
                "paragraphStyle": {"spaceAbove": pt(above), "spaceBelow": pt(below)}}})

        prev_named = named

        # Inline code: the CSS tint survived import, the font did not.
        cursor = e["startIndex"]
        for el in elements:
            tr = el.get("textRun")
            if not tr:
                cursor = el.get("endIndex", cursor)
                continue
            if is_code_run(el) and tr["content"].strip():
                style.append({"updateTextStyle": {
                    "range": {"startIndex": el["startIndex"], "endIndex": el["endIndex"]},
                    "fields": "weightedFontFamily,fontSize",
                    "textStyle": {"weightedFontFamily": {"fontFamily": MONO_FONT},
                                  "fontSize": pt(10)}}})
            cursor = el.get("endIndex", cursor)

    reqs = style + table_gaps(doc)
    if reqs:
        gws("docs", "documents", "batchUpdate",
            "--params", json.dumps({"documentId": doc_id}),
            "--json", json.dumps({"requests": reqs}))
    return len(reqs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", help="body fragment or full HTML document; omit to restyle in place")
    ap.add_argument("--title")
    ap.add_argument("--doc-id", help="replace this doc's content instead of creating one")
    a = ap.parse_args()
    if not a.title and not a.doc_id:
        sys.exit("need --title (create) or --doc-id (update)")
    if not a.html:
        if not a.doc_id:
            sys.exit("--doc-id is required to restyle in place")
        n = fixup(a.doc_id)
        print(f"restyled in place, {n} fixup requests (content untouched)")
        print(f"https://docs.google.com/document/d/{a.doc_id}/edit")
        return

    html = wrap(pathlib.Path(a.html).read_text(), a.title or "")
    # gws refuses --upload paths outside the cwd, so stage the file here.
    tmp = f".gdoc-theme-{uuid.uuid4().hex[:8]}.html"
    pathlib.Path(tmp).write_text(html)
    try:
        if a.doc_id:
            doc_id = a.doc_id
            gws("drive", "files", "update", "--params", json.dumps({"fileId": doc_id}),
                "--upload", tmp, "--upload-content-type", "text/html")
        else:
            res = gws("drive", "files", "create",
                      "--json", json.dumps({"name": a.title,
                                            "mimeType": "application/vnd.google-apps.document"}),
                      "--upload", tmp, "--upload-content-type", "text/html",
                      "--params", json.dumps({"fields": "id"}))
            doc_id = res["id"]
    finally:
        os.unlink(tmp)

    n = fixup(doc_id)
    print(f"fixup requests: {n}")
    print(f"https://docs.google.com/document/d/{doc_id}/edit")


if __name__ == "__main__":
    main()
