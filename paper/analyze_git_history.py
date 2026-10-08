"""Compute ATT's field-study metrics from a repository's git history.

Usage:
    git log origin/<base> --since=<date> --format='%H|%ad|%ae|%s' --date=iso-strict > log.txt
    python3 analyze_git_history.py            # reads log.txt, writes metrics.json

Relies on the commit formats ATT's agents and scripts write:
    "Claim #NN (L<n>) for agent/NN-slug"      (coding agent claims)
    "Merge #NN (PR #N)"                       (automerge.sh)
    "Merge train/NN (PR #N): #a #b ..."       (train_merge.sh)
and on signed worktrees ("user+<agent>@domain") to attribute commits to roles.
SUPERVISOR_DATE is when the deployment switched to supervised sessions.
"""
import re, json, statistics as st, collections, datetime as dt, sys
rows=[l.rstrip('\n').split('|',3) for l in open('log.txt')]
ev=[(dt.datetime.fromisoformat(d),e,s) for h,d,e,s in rows]
ev.sort()
claims={}; merges={}; levels={}
for t,e,s in ev:
    m=re.match(r'Claim (#\d+(?:[ ,&+and#\d]*)?)\s*\((L\d)',s)
    if m:
        for n in re.findall(r'#(\d+)',m.group(1)):
            claims.setdefault(int(n),t); levels[int(n)]=m.group(2)
    m=re.match(r'Merge #(\d+) \(PR #\d+\)',s)
    if m: merges.setdefault(int(m.group(1)),t)
    m=re.match(r'Merge train/\S+ \(PR #\d+\): (.*)',s)
    if m:
        for n in re.findall(r'#(\d+)',m.group(1)): merges.setdefault(int(n),t)
lat=[]; bylev=collections.defaultdict(list)
for n,tc in claims.items():
    if n in merges and merges[n]>tc:
        h=(merges[n]-tc).total_seconds()/3600; lat.append(h); bylev[levels[n]].append(h)
def q(xs,p): xs=sorted(xs); return xs[min(len(xs)-1,int(p*len(xs)))]
out={}
out['claims_rows']=len(claims); out['merged_rows']=len(merges); out['claimed_and_merged']=len(lat)
out['claim_to_merge_h']={'median':round(st.median(lat),2),'p25':round(q(lat,.25),2),'p75':round(q(lat,.75),2),'p90':round(q(lat,.9),2),'mean':round(st.mean(lat),2)}
out['by_level']={k:{'n':len(v),'median_h':round(st.median(v),2)} for k,v in sorted(bylev.items())}
out['claims_by_level']=dict(collections.Counter(levels.values()))
# per day merged rows and commits
day=collections.Counter(t.date().isoformat() for t in merges.values())
out['merged_rows_per_day']=dict(sorted(day.items()))
cday=collections.Counter(t.date().isoformat() for t,e,s in ev)
out['commits_per_day']=dict(sorted(cday.items()))
# roles
def role(e):
    m=re.match(r'[^@+]+\+([a-z0-9-]+)@',e)
    if m:
        a=m.group(1)
        if a.startswith('tech') : return 'tech lead'
        if a.startswith('pm') or a.startswith('goal'): return 'PM'
        if re.match(r'c\d|c-cloud',a): return 'coding agent (supervised)'
        if a.startswith(('ide', 'cursor')): return 'coding agent (IDE)'
    if 'agent@' in e and 'noreply' not in e: return 'coding agent (IDE)'
    if 'noreply@anthropic' in e: return 'cloud session'
    return 'owner / unsigned / GitHub merge'
out['commits_by_role']=dict(collections.Counter(role(e) for t,e,s in ev).most_common())
out['agent_identities']=sorted({re.match(r'[^@+]+\+([a-z0-9-]+)@',e).group(1) for t,e,s in ev if re.match(r'[^@+]+\+[a-z0-9-]+@',e)})
out['span']=[ev[0][0].isoformat(),ev[-1][0].isoformat()]
# era since supervisor 2026-10-04
SUPERVISOR_DATE=(2026,10,4)
sup=dt.datetime(*SUPERVISOR_DATE,tzinfo=ev[0][0].tzinfo)
l2=[(merges[n]-claims[n]).total_seconds()/3600 for n in claims if n in merges and merges[n]>claims[n] and claims[n]>=sup]
l1=[(merges[n]-claims[n]).total_seconds()/3600 for n in claims if n in merges and merges[n]>claims[n] and claims[n]<sup]
out['pre_supervisor']={'n':len(l1),'median_h':round(st.median(l1),2) if l1 else None}
out['post_supervisor']={'n':len(l2),'median_h':round(st.median(l2),2) if l2 else None}
out['rows_merged_pre']=sum(1 for t in merges.values() if t<sup); out['rows_merged_post']=sum(1 for t in merges.values() if t>=sup)
json.dump(out,open('metrics.json','w'),indent=1); print(json.dumps(out,indent=1))
