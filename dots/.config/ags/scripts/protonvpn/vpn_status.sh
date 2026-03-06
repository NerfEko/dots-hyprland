#!/usr/bin/env bash
# Outputs JSON describing ProtonVPN status and server list.
# Output format:
# {
#   "active": "US-NY#184",   // server name (no "ProtonVPN " prefix), empty string if none active
#   "servers": [
#     { "name": "US-NY#184", "city": "New York", "country": "US",
#       "load": 21, "score": 1.531, "fastest": true }
#   ]
# }

SERVERLIST="$HOME/.cache/Proton/VPN/serverlist.json"

# Get active ProtonVPN server name (strip "ProtonVPN " prefix)
ACTIVE=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
    | awk -F: '$2=="wireguard" && $1~/^ProtonVPN / {print substr($1, 11)}' \
    | head -1)

if [ ! -f "$SERVERLIST" ]; then
    printf '{"active":"%s","servers":[]}\n' "$ACTIVE"
    exit 0
fi

python3 - "$ACTIVE" "$SERVERLIST" <<'PYEOF'
import sys, json

active = sys.argv[1]
serverlist_path = sys.argv[2]

with open(serverlist_path) as f:
    data = json.load(f)

all_servers = [
    s for s in data.get('LogicalServers', [])
    if s.get('Status') == 1
]

# Determine country to show: active server's country, or fastest overall
active_country = None
if active:
    for s in all_servers:
        if s['Name'] == active:
            active_country = s.get('ExitCountry')
            break

# Filter to same-country servers (regular servers: ExitCountry == EntryCountry, Features excludes SecureCore)
SECURE_CORE_FEATURE = 1
def is_regular(s):
    return (s.get('Features', 0) & SECURE_CORE_FEATURE) == 0

if active_country:
    candidates = [s for s in all_servers if s.get('ExitCountry') == active_country and is_regular(s)]
else:
    candidates = [s for s in all_servers if is_regular(s)]

# Sort by score, take top 30
candidates.sort(key=lambda s: s.get('Score', 9999))
candidates = candidates[:30]

servers = []
for s in candidates:
    servers.append({
        'name':    s['Name'],
        'city':    s.get('City') or '',
        'country': s.get('ExitCountry', ''),
        'load':    s.get('Load', 0),
        'score':   round(s.get('Score', 9999), 3),
        'fastest': False,
    })

# Mark fastest (lowest score)
if servers:
    servers[0]['fastest'] = True

print(json.dumps({'active': active, 'servers': servers}))
PYEOF
