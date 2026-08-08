#!/usr/bin/env python3
"""Build the final France + Paris/Île-de-France ranked lists with percentiles, explicit
location provenance, and CSV output.

Inputs (in /tmp):
  paxel_builders.tsv      email<TAB>score  (all builders; population for percentiles)
  yc_locations.tsv        email<TAB>first<TAB>last<TAB>latest_location  (YC join)
  fr_verified.json        OPTIONAL list of web-confirmed NON-YC France builders:
                          [{"email","name","city","source","linkedin"}]
  france_linkedin.csv     OPTIONAL  email,latest_location,linkedin  (LinkedIn for YC ones)
Outputs:
  /tmp/paxel_top10_france.csv   /tmp/paxel_paris_ile_de_france.csv
Generalize: change COUNTRY substring + IDF set for another region.
"""
import json, csv, os, bisect

COUNTRY = os.environ.get('COUNTRY', 'france').lower()

def base(e):
    e = e.strip().lower()
    if '@' not in e:
        return e
    l, d = e.split('@', 1)
    return l.split('+')[0] + '@' + d

# population (best score per human)
best = {}
for line in open('/tmp/paxel_builders.tsv'):
    p = line.rstrip('\n').split('\t')
    if len(p) == 2 and '@' in p[0]:
        b = base(p[0]); sc = float(p[1])
        best[b] = max(best.get(b, 0), sc)
pop = sorted(best.values()); N = len(pop)

def quantile(q):
    return pop[min(N - 1, int(round(q * (N - 1))))]

def toppct(sc):
    return 100 - bisect.bisect_right(pop, sc) / N * 100

print(f"Population (distinct builders): {N}")
for q in (0.50, 0.90, 0.95, 0.99):
    print(f"  p{int(q*100)} = {quantile(q):.2f}")
print(f"  mean = {sum(pop)/N:.2f}   max = {pop[-1]:.2f}")

# scores per email
scores = {base(l.split('\t')[0]): float(l.split('\t')[1])
          for l in open('/tmp/paxel_builders.tsv') if '\t' in l and '@' in l}
# YC location + name
yc = {}
for line in open('/tmp/yc_locations.tsv'):
    p = line.rstrip('\n').split('\t')
    if len(p) >= 4:
        yc[p[0].lower()] = (f"{p[1]} {p[2]}".strip(), p[3])
# linkedin (optional)
li = {}
if os.path.exists('/tmp/france_linkedin.csv'):
    rdr = csv.reader(open('/tmp/france_linkedin.csv')); next(rdr, None)
    for r in rdr:
        if len(r) >= 3 and '@' in r[0]:
            li[r[0].lower()] = r[2]

people = {}  # base email -> record
for e, sc in scores.items():
    rec = yc.get(e) or yc.get(base(e))
    if rec and COUNTRY in rec[1].lower():
        people[base(e)] = {'email': e, 'score': sc, 'name': rec[0], 'location': rec[1],
                           'linkedin': li.get(e, ''), 'src': 'YC',
                           'prov': f'YC users.latest_location = "{rec[1]}"'}
# web-verified non-YC additions
if os.path.exists('/tmp/fr_verified.json'):
    for v in json.load(open('/tmp/fr_verified.json')):
        e = v['email'].lower(); b = base(e)
        people[b] = {'email': e, 'score': scores.get(b, v.get('score', 0)),
                     'name': v.get('name', ''), 'location': v.get('city', '') + ', France',
                     'linkedin': v.get('linkedin', ''), 'src': 'web',
                     'prov': v.get('source', 'web-verified (LinkedIn/GitHub)')}

ppl = sorted(people.values(), key=lambda x: -x['score'])

IDF = {'paris','rambouillet','versailles','fontainebleau','emerainville','meaux','melun',
       'boulogne-billancourt','nanterre','levallois-perret','neuilly-sur-seine','courbevoie',
       'issy-les-moulineaux','clichy','antony','saint-denis','montreuil','aubervilliers',
       'pantin','vincennes','creteil','ivry-sur-seine','vaureal','cergy','argenteuil',
       'evry','massy','palaiseau','orsay','saclay'}

def city(p):
    return p['location'].split(',')[0].split('(')[0].strip()

for p in ppl:
    p['top'] = toppct(p['score'])
    p['city'] = city(p) or COUNTRY.title()
    p['idf'] = city(p).lower() in IDF

cols = ['rank','score','percentile_vs_all','name','city','email','linkedin_or_github',
        'location_source','location_pinned_from']

def write(path, rows):
    w = csv.writer(open(path, 'w', newline='')); w.writerow(cols)
    for i, p in enumerate(rows, 1):
        src = 'web' if p['src'] == 'web' else 'YC profile (users.latest_location)'
        w.writerow([i, p['score'], f"top {p['top']:.1f}%", p['name'], p['city'], p['email'],
                    p['linkedin'], src, p['prov']])

write('/tmp/paxel_top10_france.csv', ppl[:10])
write('/tmp/paxel_paris_ile_de_france.csv', [p for p in ppl if p['idf']])
print(f"\nFrance builders: {len(ppl)}  |  Île-de-France: {sum(1 for p in ppl if p['idf'])}")
print("wrote /tmp/paxel_top10_france.csv and /tmp/paxel_paris_ile_de_france.csv")
