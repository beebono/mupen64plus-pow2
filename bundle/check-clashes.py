#!/usr/bin/env python3
"""Find global symbols defined in more than one bundle archive.

usage: check-clashes.py [--write] core=libmupen64plus.a foir=libfoir.a ...
Prints each clash.  With --write, appends the symbol to extra-<p>.txt of every
non-core, non-ui component that defines it (gen-rename.py then renames it with
that component's prefix on the next build).  'ui' is renamed only if it is
given as ui=<archive or object>.  Weak-vs-weak and common duplicates are ignored.
"""
import subprocess, sys, os, collections
here = os.path.dirname(os.path.abspath(__file__))
args = [a for a in sys.argv[1:] if a != '--write']
write = '--write' in sys.argv
defs = collections.defaultdict(dict)   # sym -> {comp: type}
for a in args:
    comp, path = a.split('=', 1)
    nm = os.environ.get('NM', 'nm')
    out = subprocess.run([nm, "-g", "--defined-only", path], capture_output=True, text=True).stdout
    for line in out.splitlines():
        f = line.split()
        if len(f) == 3 and f[1] in 'TDBRVWCiuTtdbrv' and f[1] != ' ':
            defs[f[2]].setdefault(comp, f[1])
clashes = {s: c for s, c in defs.items() if len(c) > 1 and not all(t in 'WV' for t in c.values())}
for s in sorted(clashes):
    print('%-40s %s' % (s, ' '.join('%s(%s)' % kv for kv in sorted(clashes[s].items()))))
print('%d clashing symbols' % len(clashes))
if write:
    for s, c in clashes.items():
        for comp in c:
            if comp == 'core':
                continue
            f = os.path.join(here, 'extra-%s.txt' % comp)
            have = set(l.strip() for l in open(f)) if os.path.exists(f) else set()
            if s not in have:
                open(f, 'a').write(s + '\n')
