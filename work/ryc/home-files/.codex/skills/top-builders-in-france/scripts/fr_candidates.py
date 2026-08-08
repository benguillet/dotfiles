#!/usr/bin/env python3
"""Filter unmatched (not-in-YC) high-scoring builders to French/European SIGNALS that
deserve web verification. Signals: .fr domain, European working timezone (+01/+02), or
a French given-name in the email handle. Writes /tmp/fr_candidates.json.
These are CANDIDATES ONLY — CET/CEST != France and a French name != French residence,
so each must still be web-verified (see verify_workflow.js)."""
import re, json

tz = {}
for line in open('/tmp/unmatched_tz.tsv'):
    p = line.rstrip('\n').split('\t')
    if len(p) == 2 and '@' in p[0]:
        tz[p[0].lower()] = p[1]

rows = []
for line in open('/tmp/unmatched_hi.txt'):
    p = line.rstrip('\n').split('\t')
    if len(p) == 2 and '@' in p[0]:
        rows.append((p[0].strip().lower(), float(p[1])))

FR_NAMES = set("""
jean pierre jacques michel andre philippe rene louis marcel paul henri georges nicolas
julien guillaume mathieu matthieu sebastien sylvain thibault thibaut quentin clement
maxime alexandre antoine arthur baptiste benoit cedric cyril damien david dorian emile
emilien fabien florent francois gael gauthier gautier geoffroy geoffrey gregoire hugo
ismael jeremie jeremy joachim jocelyn jordan kevin laurent leo leonard lilian loic loick
lucas ludovic marc martin mehdi morgan nathan olivier pascal remi remy romain ronan
stephane thomas tristan valentin vincent xavier yann yannick yoann adrien aurelien
bastien come corentin edouard eliott etienne ferdinand gabriel gaspard gatien hadrien
hippolyte ilan jules leandre lionel maelan malo noe oscar pacome raphael sacha samuel
simon stanislas teo theo ugo victor amelie anais camille charlotte chloe clara claire
elise emma helene ines juliette laure lea louise manon margaux marie marion mathilde
melanie noemie oceane pauline sarah sophie zoe celine sandrine virginie aurelie khaled
said ghita ilyas hamza maan briac titouan freddie alize axel quinten nikita
""".split())
PARTICLES = {"le", "la", "de", "du", "des", "saint"}
EUR_TZ = {"+01:00", "+02:00"}

def reasons(email):
    local, dom = email.split('@', 1)
    r = []
    if dom.endswith(".fr"):
        r.append("fr-domain")
    if tz.get(email, "") in EUR_TZ:
        r.append("eur-tz:" + tz[email])
    toks = [x for x in re.split(r'[._\-+0-9]+', local) if x]
    if any(t in FR_NAMES for t in toks):
        r.append("fr-name")
    if any(t in PARTICLES for t in toks):
        r.append("fr-particle")
    return r

cands = []
for e, sc in rows:
    r = reasons(e)
    if r:
        cands.append({"email": e, "score": sc, "tz": tz.get(e, ""), "reasons": ",".join(r)})
cands.sort(key=lambda x: -x["score"])
json.dump(cands, open('/tmp/fr_candidates.json', 'w'), ensure_ascii=False)
print(f"candidates={len(cands)} (from {len(rows)} unmatched)")
for c in cands:
    print(f"  {c['score']:>5}  {c['tz']:7}  {c['email']:42}  {c['reasons']}")
