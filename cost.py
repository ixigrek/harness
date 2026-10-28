#!/usr/bin/env python3
"""cost.py: token usage and API-equivalent cost of Claude Code sessions, from the local logs.

Reads every ~/.claude/projects/**/*.jsonl (main sessions and subagents), dedupes streamed
assistant messages by message id, groups by day and model. Prices are first-party API rates
(USD per MTok); on a subscription the USD column is what the same usage would have cost.

    python3 cost.py [--days N] [--by session]    (inside the VM; `harness cost` runs it via sbx exec)
"""
import glob, json, os, sys
from collections import defaultdict

# model prefix: (input, cache write 5m, cache write 1h, cache read, output)   USD / MTok, 2026-06
PRICES = {
    "claude-fable-5-1": (10, 12.5, 20, 0.25, 50),
    "claude-fable-5":   (10, 12.5, 20, 1.0, 50),
    "claude-opus-5":    (5, 6.25, 10, 0.5, 25),
    "claude-opus-4":    (5, 6.25, 10, 0.5, 25),
    "claude-sonnet-5":  (2, 2.5, 4, 0.2, 10),
    "claude-sonnet-4":  (3, 3.75, 6, 0.3, 15),
    "claude-haiku-4-5": (1, 1.25, 2, 0.1, 5),
}

def price(model):
    for k in sorted(PRICES, key=len, reverse=True):
        if model.startswith(k):
            return PRICES[k]
    return None

def usd(model, u):
    p = price(model)
    if not p:
        return 0.0
    cc = u.get("cache_creation") or {}
    w5 = cc.get("ephemeral_5m_input_tokens")
    w1 = cc.get("ephemeral_1h_input_tokens", 0)
    if w5 is None:  # older entries: no TTL breakdown, assume 5m
        w5, w1 = u.get("cache_creation_input_tokens", 0), 0
    return (u.get("input_tokens", 0) * p[0] + w5 * p[1] + w1 * p[2]
            + u.get("cache_read_input_tokens", 0) * p[3] + u.get("output_tokens", 0) * p[4]) / 1e6

def main():
    days, by = None, "day"
    a = sys.argv[1:]
    while a:
        if a[0] == "--days": days = int(a[1]); a = a[2:]
        elif a[0] == "--by": by = a[1]; a = a[2:]
        else: sys.exit(__doc__)
    root = os.path.expanduser("~/.claude/projects")
    cutoff = None
    if days:
        import datetime as dt
        cutoff = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)).isoformat()
    msgs = {}  # message id -> (day, session, model, usage)
    for f in glob.glob(f"{root}/**/*.jsonl", recursive=True):
        sess = os.path.basename(f).removesuffix(".jsonl")
        for line in open(f, errors="replace"):
            try: o = json.loads(line)
            except ValueError: continue
            if o.get("type") != "assistant": continue
            m = o.get("message") or {}
            u = m.get("usage")
            if not u or not m.get("id"): continue
            ts = o.get("timestamp", "")
            if cutoff and ts < cutoff: continue
            mid = m["id"]
            if mid in msgs and msgs[mid][3].get("output_tokens", 0) >= u.get("output_tokens", 0): continue
            msgs[mid] = (ts[:10], sess, m.get("model", "?"), u)
    agg = defaultdict(lambda: defaultdict(float))
    for day, sess, model, u in msgs.values():
        key = (day, sess[:8] if by == "session" else "", model)
        r = agg[key]
        r["turns"] += 1
        r["in"] += u.get("input_tokens", 0)
        r["cache_w"] += u.get("cache_creation_input_tokens", 0)
        r["cache_r"] += u.get("cache_read_input_tokens", 0)
        r["out"] += u.get("output_tokens", 0)
        r["usd"] += usd(model, u)
    cols = ["turns", "in", "cache_w", "cache_r", "out", "usd"]
    hdr = f"{'day':10} {'session':8} {'model':22} " + " ".join(f"{c:>9}" for c in cols)
    print(hdr)
    tot = defaultdict(float)
    for key in sorted(agg):
        r = agg[key]
        print(f"{key[0]:10} {key[1]:8} {key[2]:22} " + " ".join(
            f"{r[c]:9.2f}" if c == "usd" else f"{int(r[c]):9d}" for c in cols))
        for c in cols: tot[c] += r[c]
    print(f"{'total':42} " + " ".join(f"{tot[c]:9.2f}" if c == "usd" else f"{int(tot[c]):9d}" for c in cols))
    if not msgs: print("no usage found under", root, file=sys.stderr)

if __name__ == "__main__":
    main()
