import json, re

raw = json.load(open('tools/_nextmap_raw.json'))
PN = 'R.aget(G.playernames, R.aget(G.playernumber, 0))'


def split_concat(e):
    e = e.strip()
    if e.startswith('R.concat(') and e.endswith(')'):
        inner = e[len('R.concat('):-1]
        parts, depth, cur = [], 0, ''
        for ch in inner:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            if ch == ',' and depth == 0:
                parts.append(cur)
                cur = ''
            else:
                cur += ch
        parts.append(cur)
        return [p.strip() for p in parts]
    return [e]


def flatten(expr):
    out = ''

    def rec(e):
        nonlocal out
        e = e.strip()
        if e.startswith('R.concat(') and e.endswith(')'):
            for p in split_concat(e):
                rec(p)
        elif 'playernames' in e:
            out += '%s'
        else:
            m = re.match(r'^"(.*)"$', e, re.S)
            out += m.group(1) if m else e

    rec(expr.strip())
    return out


lines_out = []
lines_out.append('## Inter-map briefings — objects/ui/next_map_obj.gd ev_0_0_N')
lines_out.append('## (room 44): the hero/toad banter flown during the')
lines_out.append('## inter-map warp. Keyed by destination world (1-7); each')
lines_out.append('## line is "SPEAKER|text" — 0 = hero (top box), 1 = toad')
lines_out.append('## (bottom-left box) per g_ktogada. %s = hero name.')
lines_out.append('const NEXT_MAP := {')
for dest in range(1, 8):
    mn = dest - 1
    entries = raw[str(mn)]
    lines_out.append('\t%d: [' % dest)
    for k, txt in entries:
        spk = '0' if k == 0 else '1'
        clean = flatten(txt).replace('\\', '\\\\').replace('"', '\\"')
        lines_out.append('\t\t"%s|%s",' % (spk, clean))
    lines_out.append('\t],')
lines_out.append('}')
open('tools/_nextmap_table.txt', 'w').write('\n'.join(lines_out))
print('\n'.join(lines_out[:25]))
print('... total lines', len(lines_out))
