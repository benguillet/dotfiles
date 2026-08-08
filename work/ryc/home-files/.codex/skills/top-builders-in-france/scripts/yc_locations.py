#!/usr/bin/env python3
"""Batch-resolve YC users.latest_location for every Paxel builder email.
Reads /tmp/paxel_builders.tsv (email<TAB>score) -> writes /tmp/yc_locations.tsv
(email<TAB>first_name<TAB>last_name<TAB>latest_location).
KEY GOTCHA: `ycli tool select-query` chokes on large IN lists; keep batches <=120.
"""
import json, subprocess, sys, csv as csvmod, io

BUILDERS = '/tmp/paxel_builders.tsv'
OUT = '/tmp/yc_locations.tsv'

def base(e):
    l, d = e.split('@', 1)
    return l.split('+')[0] + '@' + d

emails = []
for line in open(BUILDERS):
    p = line.rstrip('\n').split('\t')
    if len(p) == 2 and '@' in p[0]:
        emails.append(p[0].strip().lower())
seen, uniq = set(), []
for e in emails:
    if e not in seen:
        seen.add(e); uniq.append(e)
variants = set(uniq)
for e in uniq:                          # also try plus-stripped alias -> base
    if '+' in e.split('@')[0]:
        variants.add(base(e))
allv = sorted(variants)
print(f"builders={len(uniq)} query_emails={len(allv)}", file=sys.stderr)

def q(batch):
    inlist = ",".join("'" + e.replace("'", "''") + "'" for e in batch)
    query = ("SELECT lower(email) AS email, first_name, last_name, latest_location "
             f"FROM users WHERE lower(email) IN ({inlist})")
    out = subprocess.run(["ycli", "tool", "select-query", "--limit", "5000", "--query", query],
                         capture_output=True, text=True)
    s = out.stdout.strip()
    try:
        d = json.loads(s)
    except Exception as ex:
        print(f"PARSE FAIL len={len(s)} err={ex}", file=sys.stderr)
        return None
    rows = list(csvmod.reader(io.StringIO(d.get("results_csv", ""))))
    return rows[1:] if rows else []

B, results, fails = 100, {}, []
for i in range(0, len(allv), B):
    r = q(allv[i:i + B])
    if r is None:
        fails.append(allv[i:i + B]); continue
    for row in r:
        if len(row) >= 4:
            results[row[0].lower()] = row
print(f"pass1 matches={len(results)} failed_batches={len(fails)}", file=sys.stderr)
for batch in fails:                     # retry failed batches smaller
    for j in range(0, len(batch), 30):
        r = q(batch[j:j + 30])
        if r:
            for row in r:
                if len(row) >= 4:
                    results[row[0].lower()] = row
with open(OUT, 'w') as out:
    for e, r in results.items():
        out.write("\t".join((r + ["", "", "", ""])[:4]) + "\n")
print(f"WROTE {len(results)} -> {OUT}", file=sys.stderr)
