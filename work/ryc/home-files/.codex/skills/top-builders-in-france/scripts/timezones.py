#!/usr/bin/env python3
"""Pull inferred working timezone for unmatched (not-in-YC) builders scoring >= MIN.
Reads /tmp/paxel_builders.tsv + /tmp/yc_locations.tsv; writes /tmp/unmatched_hi.txt
(email<TAB>score) and /tmp/unmatched_tz.tsv (email<TAB>offset_string).
Timezone lives in uploads.builder_profile_data->'inferred_timezone'->>'offset_string'.
European offsets (+01:00/+02:00) are a NECESSARY (not sufficient) condition for France.
"""
import subprocess, os

MIN = float(os.environ.get('MIN_SCORE', '7.0'))
PG = ["psql", "-h", "localhost", "-p", "5434", "-U", "postgres", "-d", "paxel_analytics",
      "-tA", "-F", "\t"]
ENV = {**os.environ, "PGPASSWORD": "postgres"}

def basemail(e):
    l, d = e.split('@', 1)
    return l.split('+')[0] + '@' + d

scores = {}
for line in open('/tmp/paxel_builders.tsv'):
    p = line.rstrip('\n').split('\t')
    if len(p) == 2 and '@' in p[0]:
        scores[p[0].strip().lower()] = float(p[1])
loc = set()
for line in open('/tmp/yc_locations.tsv'):
    p = line.rstrip('\n').split('\t')
    if p and p[0]:
        loc.add(p[0].lower())

um, seen = [], set()
for e, sc in sorted(scores.items(), key=lambda x: -x[1]):
    b = basemail(e)
    if b in seen or e in loc or b in loc:
        continue
    seen.add(b); um.append((e, sc))
hi = [(e, sc) for e, sc in um if sc >= MIN]
open('/tmp/unmatched_hi.txt', 'w').write("\n".join(f"{e}\t{sc}" for e, sc in hi))
print(f"unmatched>={MIN}: {len(hi)}")

inlist = ",".join("'" + e.replace("'", "''") + "'" for e, _ in hi)
sql = f"""
WITH best AS (
  SELECT DISTINCT ON (u.user_id) u.user_id,
    (u.builder_profile_data->'inferred_timezone'->>'offset_string') AS tz
  FROM uploads u WHERE u.status='complete' AND u.user_id IS NOT NULL
    AND lower((SELECT email FROM users WHERE id=u.user_id)) IN ({inlist})
  ORDER BY u.user_id, (u.v3_results->'overall'->>'score')::numeric DESC NULLS LAST)
SELECT lower(us.email), b.tz FROM best b JOIN users us ON us.id=b.user_id;"""
out = subprocess.run(PG + ["-c", sql], capture_output=True, text=True, env=ENV)
open('/tmp/unmatched_tz.tsv', 'w').write(
    "\n".join(l for l in out.stdout.splitlines() if '@' in l) + "\n")
print("wrote /tmp/unmatched_tz.tsv")
