#!/usr/bin/env python3
"""Cross-reference the France/IDF CSVs against a YC event's invite list.
Usage: python3 xref_event.py <meetup_id>
Dumps meetup_rsvps (joined to YC users) and adds an `event_status` column to both CSVs.

Invite semantics (status -> meaning):
  confirmed/invite_pending/invite_expired/declined  -> INVITED (invited_at is set)
  applied / *_waitlist                              -> applied (self-applied, no invite yet)
  rejected                                          -> applied -> rejected
  (no row)                                          -> not in list  (proactive-invite target)
Always also grep the raw dump for surnames of 'not in list' people to catch alt-email RSVPs.
"""
import sys, json, subprocess, csv, io

if len(sys.argv) < 2:
    sys.exit("usage: xref_event.py <meetup_id>")
MID = sys.argv[1]

def base(e):
    e = e.strip().lower()
    if '@' not in e:
        return e
    l, d = e.split('@', 1)
    return l.split('+')[0] + '@' + d

q = (f"SELECT lower(u.email) AS email, u.first_name, u.last_name, r.status, "
     f"(r.invited_at IS NOT NULL) AS invited "
     f"FROM meetup_rsvps r JOIN users u ON u.id=r.user_id WHERE r.meetup_id={MID}")
out = subprocess.run(["ycli", "tool", "select-query", "--limit", "20000", "--query", q],
                     capture_output=True, text=True)
d = json.loads(out.stdout)
open('/tmp/event_rsvps.csv', 'w').write(d.get('results_csv', ''))
print(f"dumped {d.get('row_count')} RSVPs -> /tmp/event_rsvps.csv")

by_email, by_name = {}, {}
for r in csv.DictReader(io.StringIO(d.get('results_csv', ''))):
    em = (r.get('email') or '').lower()
    if em:
        by_email[em] = r['status']; by_email[base(em)] = r['status']
    nm = (f"{r.get('first_name','')} {r.get('last_name','')}").strip().lower()
    if nm:
        by_name[nm] = r['status']

LABEL = {'confirmed': 'INVITED - confirmed', 'invite_pending': 'INVITED - awaiting reply',
         'invite_expired': 'INVITED - expired', 'declined': 'INVITED - declined',
         'applied': 'applied (not yet invited)', 'rejoined_waitlist': 'applied - waitlist',
         'left_waitlist': 'applied - left waitlist', 'rejected': 'applied - rejected'}

def status(email, name):
    s = by_email.get(email.lower()) or by_email.get(base(email)) or by_name.get(name.strip().lower())
    return LABEL.get(s, s) if s else 'not in event list'

for path in ('/tmp/paxel_top10_france.csv', '/tmp/paxel_paris_ile_de_france.csv'):
    rows = list(csv.reader(open(path)))
    hdr, body = rows[0], rows[1:]
    ei, ni = hdr.index('email'), hdr.index('name')
    if 'event_status' not in hdr:
        hdr.append('event_status')
    w = csv.writer(open(path, 'w', newline='')); w.writerow(hdr)
    for r in body:
        st = status(r[ei], r[ni])
        if len(r) < len(hdr):
            r.append(st)
        else:
            r[-1] = st
        w.writerow(r)
    print(f"updated {path}")
    for r in body:
        print(f"  {r[1]:>5}  {r[3][:22]:22}  {status(r[ei], r[ni])}")
