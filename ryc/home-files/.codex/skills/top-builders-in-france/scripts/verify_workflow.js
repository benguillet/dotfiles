// Workflow template: web-verify French/European-signal builders for France/Paris residence.
// Usage: prepend the candidate array, then run via the Workflow tool.
//   1) python3 fr_candidates.py   (writes /tmp/fr_candidates.json)
//   2) build the array:  const CANDIDATES = <contents of fr_candidates.json>;
//      (read the json and inline it ABOVE this comment block — workflow scripts can't read files)
//   3) Workflow({ script: "<this file with CANDIDATES prepended>" })
// Pattern: locate (web search) -> adversarial France verify. Default to NOT-France on weak
// evidence. Guard rails: CET/CEST covers DE/ES/IT/UK-summer/IE/PT/Nordics (NOT just France);
// a French name does NOT prove French residence.

export const meta = {
  name: 'verify-france-builders',
  description: 'Web-verify French/European-signal builders for France/Paris residence',
  phases: [ { title: 'Locate' }, { title: 'Verify' } ],
}

// const CANDIDATES = [ {email, score, tz, reasons}, ... ]   // <-- prepend before running

const LOC = {
  type: 'object',
  required: ['email','name','country','city','in_france','in_paris','confidence','evidence'],
  properties: {
    email:{type:'string'}, name:{type:'string'}, country:{type:'string'}, city:{type:'string'},
    in_france:{type:'boolean'}, in_paris:{type:'boolean'},
    confidence:{type:'string',enum:['high','medium','low']}, evidence:{type:'string'},
  },
}
const VERDICT = {
  type: 'object',
  required: ['email','in_france_confirmed','in_paris_confirmed','country','city','confidence','reasoning'],
  properties: {
    email:{type:'string'}, in_france_confirmed:{type:'boolean'}, in_paris_confirmed:{type:'boolean'},
    country:{type:'string'}, city:{type:'string'},
    confidence:{type:'string',enum:['high','medium','low']}, reasoning:{type:'string'},
  },
}

const results = await pipeline(
  CANDIDATES,
  (c) => agent(
    `Determine whether this developer CURRENTLY LIVES IN FRANCE (and specifically Paris).
Email: ${c.email}
Signals: working timezone "${c.tz || 'unknown'}", heuristic reasons: ${c.reasons}.
Load WebSearch + WebFetch via ToolSearch ("select:WebSearch,WebFetch"). Check, in priority
order: (1) LinkedIn 'location' field + current employer; (2) GitHub profile 'location' field
+ company; (3) the email domain's company site ("based in"/team page); (4) Crunchbase / X /
personal site. Distinguish CURRENT residence from company HQ. CRITICAL: a +01:00/+02:00 timezone covers
Germany/Spain/Italy/Belgium/Netherlands/Switzerland/Nordics/UK-summer/Ireland/Portugal —
NOT just France; and a French-sounding name does NOT prove French residence. Only set
in_france=true with real CURRENT-residence evidence; else country/city="unknown",
in_france=false, confidence=low. in_paris=true ONLY for Paris city / immediate
Île-de-France core (e.g. Boulogne-Billancourt, Saint-Denis, Émerainville) — not distant French cities.`,
    { label: c.email, phase: 'Locate', schema: LOC }
  ),
  (loc, c) => {
    if (!loc || !loc.in_france) return loc
    return agent(
      `Adversarially verify: someone claims this person currently lives in France${loc.in_paris ? ', specifically Paris' : ''}.
Email: ${c.email}
Claim: name="${loc.name}", country="${loc.country}", city="${loc.city}", in_paris=${loc.in_paris}
Evidence offered: ${loc.evidence}
Load WebSearch + WebFetch via ToolSearch. TRY TO REFUTE: search for evidence they live
elsewhere. Confirm France only if evidence genuinely supports CURRENT residence in France.
Be strict on Paris (Paris city / immediate Île-de-France only). Default to NOT confirmed
if evidence is weak or conflicting.`,
      { label: `verify:${c.email}`, phase: 'Verify', schema: VERDICT }
    ).then((v) => ({ ...loc, verdict: v }))
  }
)
return results.filter(Boolean)
