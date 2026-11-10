#!/usr/bin/env python3
"""Nykle.win primordial config builder.

Builds primordial/Nykle.win.cfg (base64 of compact JSON, same encoding as primordial's own .cfg files)
and primordial/Nykle.win.cfg.json (pretty, for reading) from:
  - KIZ4RU (AA base, keys, exploits, misc)            -> the starting tree
  - A RazGamesensical (ragebot weapon blocks)          -> primordial/Aimbot/<7 weapons>
  - BRIEF section 3 tables A-D (FRAGMENT DT hitchance, kucjlota wall gate, neutral native AA, ...)
  - the " Scripts"/"Nykle.win" subtree generated from the ACTUAL menu of primordial/Nykle.win.lua
    (tools/prim_menu_dump.lua runs the script under luajit with a recording mock menu API).

Run:  python3 -I tools/build_prim_cfg.py [--src DIR]
  DIR holds the original (third-party) primordial configs; they are read as data only.
  Default: $NYKLE_PRIM_SRC or the session scratchpad "prim" folder.
"""
import base64
import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "primordial", "Nykle.win.lua")
DUMPER = os.path.join(REPO, "tools", "prim_menu_dump.lua")
OUT_CFG = os.path.join(REPO, "primordial", "Nykle.win.cfg")
OUT_JSON = os.path.join(REPO, "primordial", "Nykle.win.cfg.json")
DEFAULT_SRC = ("/tmp/claude-0/-home-user-NEVERLOSE-ANT-A-M/54960ccb-7c44-5245-9c51-6f7cf6a6271c/"
               "scratchpad/prim")
KIZ_REL = "rar/nested/kizaru1337's modified cfg hackvshack.net/KIZ4RU"
RAZ_REL = "zip/primordial/configs/A RazGamesensical"
SCRIPT_KEY = "Nykle.win"
WEAPONS = ["Scout", "AWP", "Auto", "Deagle", "Revolver", "Pistols", "Other"]
UNBOUND = {"key": 0, "mode": 4}
# Source ButtonCode: CAPSLOCK 68 has no default CS:GO bind (G = drop, Z = radio1 are avoided).
KEY_CAPSLOCK, KEY_MOUSE4, KEY_MOUSE5 = 68, 110, 111
KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_LSHIFT = 89, 91, 90, 79


def encode(tree):
    """primordial's .cfg = base64(compact JSON, keys sorted, UTF-8 not escaped)."""
    js = json.dumps(tree, separators=(",", ":"), ensure_ascii=False, sort_keys=True).encode("utf-8")
    return base64.b64encode(js)


def load_original(path):
    raw = open(path, "rb").read().strip()
    js = base64.b64decode(raw, validate=True)
    tree = json.loads(js.decode("utf-8"))
    # Round-trip check: our encoder must reproduce the original byte for byte.
    if encode(tree) != raw:
        sys.exit("encoding round-trip FAILED for " + path)
    return tree


class Editor:
    def __init__(self, tree):
        self.tree = tree

    def node(self, path, create=False):
        n = self.tree
        for k in path:
            if k not in n:
                if not create:
                    sys.exit("missing path: " + "/".join(path))
                n[k] = {}
            n = n[k]
        return n

    def set(self, path, value):
        """Set an existing leaf dict (or plain value) at path; never invents native keys."""
        parent = self.node(path[:-1])
        if path[-1] not in parent:
            sys.exit("missing path: " + "/".join(path))
        parent[path[-1]] = value

    def cb(self, path, on):
        self.set(path, {"is active": bool(on)})

    def sl(self, path, v):
        self.set(path, {"value": float(v)})

    def sel(self, path, idx0):
        node = self.node(path)
        if "active item" not in node:
            sys.exit("not a selection: " + "/".join(path))
        node["active item"] = int(idx0)

    def bind(self, path, key, mode):
        self.set(path, {"key": int(key), "mode": int(mode)})

    def multi(self, path, active):
        node = self.node(path)
        names = [k for k, v in node.items() if isinstance(v, dict) and "is active" in v]
        for a in active:
            if a not in names:
                sys.exit("unknown multi item %s at %s" % (a, "/".join(path)))
        for k in names:
            node[k] = {"is active": k in active}


# ----------------------------------------------------------------------------------------------
# Tables A-D (BRIEF section 3.3)
# ----------------------------------------------------------------------------------------------
def apply_antiaim(e):
    m = ["primordial", "Antiaim", "Main"]
    g, a, d = m + ["General"], m + ["Angles"], m + ["Desync"]
    e.bind(g + ["Enable", "Enable Key"], 0, 3)
    e.bind(g + ["Fakeduck", "Fakeduck Key"], KEY_MOUSE4, 1)
    for k in ("Anti Knife", "Fast Ladder Move", "Ladder Antiaim"):
        e.cb(g + [k], True)
    e.sel(g + ["Leg Slide"], 2)
    e.multi(g + ["Disable States"], ["Freezetime"])
    e.bind(g + ["Lock Angle", "Lock Angle Key"], 0, 4)
    e.sel(a + ["Pitch"], 1)
    e.sel(a + ["Yaw Base"], 2)
    e.sl(a + ["Yaw Add"], 0)
    e.sl(a + ["Jitter Add"], 0)
    e.sel(a + ["Jitter Mode"], 0)
    e.sel(a + ["Jitter Type"], 1)
    e.cb(a + ["Rotate"], False)
    e.sel(a + ["Body Lean"], 0)
    e.cb(a + ["Moving Body Lean"], False)
    x = m + ["Extended Angles"]
    e.bind(x + ["Enable", "Enable Key"], 0, 4)
    e.cb(x + ["Enable While Moving"], False)
    e.sel(d + ["Side#Stand"], 1)
    e.sel(d + ["Default Side#Stand"], 0)
    e.sl(d + ["Left Amount#Stand"], 100)
    e.sl(d + ["Right Amount#Stand"], 100)
    e.cb(d + ["Override Stand#Move"], False)
    e.cb(d + ["Override Stand#Slow Walk"], False)
    e.sel(d + ["Side#Move"], 1)
    e.sel(d + ["Side#Slow Walk"], 1)
    e.cb(d + ["Anti Bruteforce"], False)
    e.sel(d + ["On Shot"], 0)
    f = m + ["Fakelag"]
    e.sl(f + ["Amount"], 15)
    e.cb(f + ["Break Lag Compensation"], True)
    ad = m + ["Auto Direction"]
    e.bind(ad + ["Enable", "Enable Key"], KEY_MOUSE5, 1)
    e.multi(ad + ["States"], ["Air", "Move", "Stand"])
    e.sel(ad + ["Target Selection"], 0)
    e.cb(ad + ["Disable Jitter"], True)
    e.cb(ad + ["Disable Rotate"], True)
    mn = m + ["Manual"]
    e.bind(mn + ["Left", "Left Key"], KEY_LEFT, 0)
    e.bind(mn + ["Right", "Right Key"], KEY_RIGHT, 0)
    e.bind(mn + ["Back", "Back Key"], KEY_DOWN, 0)
    e.cb(mn + ["Disable Jitter"], True)
    e.cb(mn + ["Disable Rotate"], True)
    e.bind(mn + ["Invert Desync", "Invert Desync Key"], 0, 4)
    e.bind(mn + ["Invert Body Lean", "Invert Body Lean Key"], 0, 4)


def apply_general(e):
    g = ["primordial", "Aimbot", "General"]
    dt = g + ["Exploits", "Doubletap"]
    # DT always on: only bind slot 0, mode 3 (KIZ4RU's extra C / MOUSE5 slots are dropped).
    e.node(dt + ["Enable"])["Doubletap Key"] = {"0": {"Doubletap Key": {"key": 0, "mode": 3}}}
    # Hideshots unbound: KIZ4RU's Z toggle is CS:GO's radio1 key, and DT is always on anyway.
    e.node(g + ["Exploits", "Hideshots", "Enable"])["Hideshots Key"] = {"0": {"Hideshots Key": dict(UNBOUND)}}
    e.cb(dt + ["Anti-Prediction On Peek"], True)
    e.cb(dt + ["Anti-Prediction In Air"], False)
    e.cb(dt + ["Shift On Knife"], True)
    # V1.0.12 vur-kac: peek tusu (MOUSE5, basili tut) basiliyken atis DT sarjini harcamaz; sarj geri isinlanmaya kalir.
    e.bind(dt + ["Dont Use Charge", "Dont Use charge key"], 111, 1)
    e.cb(g + ["Exploits", "Force Prediction"], False)
    e.bind(g + ["Exploits", "Instant Recharge", "Key"], 0, 4)
    e.sl(g + ["Exploits", "Uncharge Delay"], 11)
    e.node(g + ["Misc", "Autopeek"])["Autopeek"] = {"0": {"Autopeek": {"key": KEY_MOUSE5, "mode": 1}}}
    e.node(g + ["Misc", "Autopeek Mode"])["active item"] = 1
    e.cb(g + ["Misc", "Knifebot"], True)
    e.sl(g + ["Misc", "Zeusbot Hitchance"], 80)
    ab = g + ["Aimbot"]
    e.bind(ab + ["Enable", "Enable Key"], 0, 3)
    for k in ("Autofire", "Silent Aim", "Shoot Through Walls", "Resolve Antiaim"):
        e.cb(ab + [k], True)
    e.bind(ab + ["Body Lean Resolver", "Body Lean Resolver Key"], 0, 4)
    e.bind(ab + ["Override Resolver", "Override Resolver Keys"], 0, 4)
    e.bind(g + ["Fake Ping", "Enable", "Enable Key"], 0, 4)
    e.bind(g + ["Dormant Aimbot", "Enable", "Enable Key"], 0, 4)
    e.sl(g + ["Dormant Aimbot", "Max Misses"], 2)
    e.cb(g + ["Debug", "Aimbot Logs"], False)


HB = {"H": "Head", "C": "Chest", "A": "Arms", "S": "Stomach", "L": "Legs", "F": "Feet"}


def hb(letters):
    return [HB[c] for c in letters]


# None = keep Raz. Order: Scout, AWP, Auto, Deagle, Revolver, Pistols, Other.
WEAPON_TABLE = {
    "hitchance": [76, 80, 68, 70, 66, 60, 55],
    "dt_hitchance": [None, None, 60, 65, 15, 35, 45],
    "noscope": [65, 75, 55, None, None, None, None],
    "dynamic_hc": [False, True, False, False, False, False, False],
    "min_damage": [100, 100, 42, 46, 100, 32, 26],
    "autowall": [None, None, 30, 34, None, None, None],
    "scale_hp": [True, True, True, True, True, False, False],
    "hitboxes": ["HCSL", "HCASLF", "HCASL", "HCSL", "HCASL", "HCS", "HCASL"],
    "multipoints": ["HCS"] * 7,
    "mp_scale": [(65, 57), (75, 65), (54, 68), (57, 65), (54, 67), (70, 55), None],
    "prefer": ["CS", "CS", "S", "S", "CS", "H", "H"],
    "ignore_limbs": [True, False, True, True, False, True, True],
    "safepoint": [1, 1, 1, 1, 1, 0, 0],
    "safe_hitboxes": ["ALF", "HCALF", "HCALF", "CS", "HALF", "CS", "CS"],
    "force_sp": [["On Enemy Shot"], ["On Enemy Shot"], ["Second Doubletap Shot", "On Enemy Shot"],
                 ["Second Doubletap Shot"], ["On Enemy Shot"], [], []],
    "options": [["Early", "Delay Shot Until Fully Accurate"], ["Early", "Delay Shot Until Fully Accurate"],
                ["Stop Between Shots", "Delay Shot Until Fully Accurate"],
                ["Stop Between Shots", "Early", "Delay Shot Until Fully Accurate"],
                ["Early", "Delay Shot Until Fully Accurate"], ["Stop Between Shots", "Early"],
                ["Stop Between Shots"]],
    "autoscope": [1, 1, 0, None, None, None, 0],
    "md_override": [7, 8, 4, 6, 7, 10, 4],
}


def apply_weapons(e, raz):
    for i, w in enumerate(WEAPONS):
        e.tree["primordial"]["Aimbot"][w] = json.loads(json.dumps(raz["primordial"]["Aimbot"][w]))
        b = ["primordial", "Aimbot", w]
        t, hs, sf, ac = b + ["Targeting"], b + ["Hitbox Selection"], b + ["Safety"], b + ["Accuracy"]
        T = {k: v[i] for k, v in WEAPON_TABLE.items()}
        e.sl(t + ["Hitchance"], T["hitchance"])
        if T["dt_hitchance"] is not None:
            e.sl(t + ["Doubletap Hitchance"], T["dt_hitchance"])
        if T["noscope"] is not None:
            e.sl(t + ["Noscope Hitchance"], T["noscope"])
        e.cb(t + ["Dynamic Hitchance"], T["dynamic_hc"])
        e.sl(t + ["Min. Damage"], T["min_damage"])
        e.cb(t + ["Override Autowall Damage"], T["autowall"] is not None)
        e.sl(t + ["Autowall"], T["autowall"] or 0)
        e.cb(t + ["Scale Damage Based On HP"], T["scale_hp"])
        e.multi(hs + ["Hitboxes"], hb(T["hitboxes"]))
        e.multi(hs + ["Multipoints"], hb(T["multipoints"]))
        if T["mp_scale"] is None:
            e.cb(hs + ["Override Max Multipoint Scale"], False)
            e.sl(hs + ["Max Head Multipoint Scale"], 70)
            e.sl(hs + ["Max Body Multipoint Scale"], 70)
        else:
            e.cb(hs + ["Override Max Multipoint Scale"], True)
            e.sl(hs + ["Max Head Multipoint Scale"], T["mp_scale"][0])
            e.sl(hs + ["Max Body Multipoint Scale"], T["mp_scale"][1])
        e.multi(hs + ["Prefer Hitboxes"], hb(T["prefer"]))
        e.cb(hs + ["Ignore Limbs If Moving"], T["ignore_limbs"])
        e.sel(sf + ["Safepoint"], T["safepoint"])
        e.multi(sf + ["Safe Hitboxes"], hb(T["safe_hitboxes"]))
        e.multi(sf + ["Force Safepoint States"], T["force_sp"])
        e.cb(ac + ["Autostop"], True)
        e.multi(ac + ["Options"], T["options"])
        if T["autoscope"] is not None:
            e.sel(b + ["General", "Autoscope"], T["autoscope"])
        e.sel(b + ["General", "Target selection"], 0)
        to = b + ["Target Overrides"]
        e.node(to + ["Min. Damage"])["value"] = float(T["md_override"])
        # Hold (mode 1) on Caps Lock: cannot stay on by accident (KIZ4RU's G toggle is CS:GO's drop key).
        e.node(to + ["Min. Damage", "Force Min. Damage Key", "0"])["Force Min. Damage Key"] = {"key": KEY_CAPSLOCK,
                                                                                               "mode": 1}
        for grp, key in (("Hitchance", "Force Hitchance Key"), ("Hitbox", "Force Hitbox Key"),
                         ("Safepoint", "Force Safepoint Key"), ("Lethal Shot", "Force Lethal Shot Key"),
                         ("Body Lean Safepoint", "Force Body Lean Safepoint Key")):
            e.node(to + [grp, key, "0"])[key] = dict(UNBOUND)


def apply_misc(e):
    mv = ["primordial", "Misc", "Main", "Movement"]
    e.bind(mv + ["Slow Walk", "slow walk key"], KEY_LSHIFT, 1)
    e.sl(mv + ["Speed"], 100)
    for k in ("Fast Stop", "Infinite Duck Stamina", "Bunnyhop", "Autostrafer"):
        e.cb(mv + [k], True)
    # E is USE: Nykle's "Legit AA on use" (default on) needs it, so Edge Jump stays unbound.
    e.bind(mv + ["Edge Jump", "edge jump key"], 0, 4)
    bb = ["primordial", "Misc", "Utility", "Buybot"]
    e.cb(bb + ["Enable"], True)
    e.sel(bb + ["Primary"], 2)
    e.sel(bb + ["Secondary"], 4)
    e.sel(bb + ["Fallback Primary"], 2)
    e.multi(bb + ["Equipment"], ["Armor", "Helmet", "Defuser", "Zeus"])
    e.multi(bb + ["Grenades"], ["Fire", "High Explosive", "Smoke"])
    ug = ["primordial", "Misc", "Utility", "General"]
    for k in ("Fast nade", "Unlock Inventory", "Auto Pistol", "Show Hidden Cvars", "Filter Console"):
        e.cb(ug + [k], True)
    # The grenade helper was rejected by the user: KIZ4RU had it always on with Autothrow on MOUSE1 hold.
    nh = ["primordial", "Misc", "Nade Helper", "General"]
    e.bind(nh + ["Enable", "Enable Key"], 0, 4)
    e.bind(nh + ["Autothrow", "Autothrow Key"], 0, 4)


# ----------------------------------------------------------------------------------------------
# Script subtree from the real menu
# ----------------------------------------------------------------------------------------------
def color_dict(r, g, b, a):
    return {"a": a, "b": b, "g": g, "mode": 0, "p_ca": a, "p_ca1": a, "p_cb": b, "p_cb1": b, "p_cg": g,
            "p_cg1": g, "p_cr": r, "p_cr1": r, "pulse_speed": 0.5, "r": r, "rainbow_alpha": a,
            "rainbow_brightness": 1.0, "rainbow_saturation": 1.0, "rainbow_speed": 0.5}


def dump_menu():
    try:
        res = subprocess.run(["luajit", DUMPER, SCRIPT], capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        sys.exit("menu dump failed (luajit needed): %s" % exc)
    groups, elems, colors = [], [], []
    for line in res.stdout.decode("utf-8").splitlines():
        f = line.split("\t")
        if f[0] == "G":
            groups.append((f[1], None if f[2] == "-" else int(f[2])))
        elif f[0] == "E":
            elems.append(f[1:])
        elif f[0] == "C":
            colors.append(f[1:])
    if not groups or len(elems) < 50:
        sys.exit("menu dump looks empty: %d groups, %d elements" % (len(groups), len(elems)))
    return groups, elems, colors


def script_subtree(groups, elems, colors):
    sub = {}
    for order, (g, col) in enumerate(groups):
        sub[g] = {"column": (col - 1) if col else 0, "is collapsed": False, "order": order}
    for g, name, kind, value, *rest in elems:
        if name in sub[g]:
            sys.exit("duplicate element name (config key clash): %s / %s" % (g, name))
        if kind == "cb":
            sub[g][name] = {"is active": value == "true"}
        elif kind == "sl":
            sub[g][name] = {"value": float(value)}
        elif kind == "sel":
            n = int(rest[0])
            idx = int(value)
            if not 1 <= idx <= n:
                sys.exit("selection default out of range: %s / %s = %d of %d" % (g, name, idx, n))
            sub[g][name] = {"active item": idx - 1}
        else:
            sys.exit("unknown kind " + kind)
    for g, host, cname, rgba in colors:
        r, gg, b, a = (int(x) for x in rgba.split(","))
        sub[g][host][cname] = color_dict(r, gg, b, a)
    return sub, len(elems)


def apply_scripts(e, sub):
    s = e.tree["primordial"][" Scripts"]
    main = s["Main"]
    for k in [k for k in s if k != "Main"]:
        del s[k]
    s[SCRIPT_KEY] = sub
    main["General"]["Available scripts"] = {"active item": SCRIPT_KEY}
    loaded = main["Loaded Scripts"]
    for k in [k for k, v in loaded.items() if isinstance(v, dict)]:
        del loaded[k]
    loaded[SCRIPT_KEY] = {"column": -1, "is collapsed": False, "order": -1}
    e.tree["scripts"] = [list(SCRIPT_KEY.encode("utf-8"))]


# ----------------------------------------------------------------------------------------------
def flat(n, p=(), out=None):
    if out is None:
        out = {}
    if isinstance(n, dict) and n:
        for k, v in n.items():
            flat(v, p + (k,), out)
    else:
        out[p] = n
    return out


def summarize(base, new):
    a, b = flat(base), flat(new)
    changed = sorted(k for k in a.keys() & b.keys() if a[k] != b[k])
    added = sorted(b.keys() - a.keys())
    removed = sorted(a.keys() - b.keys())
    print("diff vs KIZ4RU: %d leaves changed, %d added, %d removed" % (len(changed), len(added), len(removed)))
    buckets = {}
    for kind, keys in (("changed", changed), ("added", added), ("removed", removed)):
        for k in keys:
            top = "/".join(k[:3]) if k[0] == "primordial" else k[0]
            buckets.setdefault(top, {"changed": 0, "added": 0, "removed": 0})[kind] += 1
    for top in sorted(buckets):
        c = buckets[top]
        print("  %-40s changed %4d  added %4d  removed %4d" % (top, c["changed"], c["added"], c["removed"]))
    print("changed native leaves (outside weapons / scripts):")
    for k in changed:
        if k[0] == "primordial" and k[1] in ("Antiaim", "Misc") or k[:3] == ("primordial", "Aimbot", "General"):
            print("  %s: %s -> %s" % ("/".join(k), json.dumps(a[k]), json.dumps(b[k])))
    for k in added:
        if k[:2] != ("primordial", " Scripts"):
            print("  + %s = %s" % ("/".join(k), json.dumps(b[k])))
    return changed, added, removed


def main():
    args = sys.argv[1:]
    src = args[1] if args[:1] == ["--src"] and len(args) > 1 else os.environ.get("NYKLE_PRIM_SRC", DEFAULT_SRC)
    kiz = load_original(os.path.join(src, KIZ_REL))
    raz = load_original(os.path.join(src, RAZ_REL))
    print("round-trip OK: KIZ4RU and A RazGamesensical re-encode byte-identically")
    base = json.loads(json.dumps(kiz))
    e = Editor(kiz)
    apply_weapons(e, raz)
    apply_antiaim(e)
    apply_general(e)
    apply_misc(e)
    groups, elems, colors = dump_menu()
    sub, n = script_subtree(groups, elems, colors)
    apply_scripts(e, sub)
    data = encode(e.tree)
    with open(OUT_CFG, "wb") as fh:
        fh.write(data)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(e.tree, fh, ensure_ascii=False, sort_keys=True, indent=1)
        fh.write("\n")
    # Self-check: decode what we wrote.
    back = json.loads(base64.b64decode(open(OUT_CFG, "rb").read()).decode("utf-8"))
    assert back == e.tree and encode(back) == data
    print("script subtree: %d groups, %d elements, %d color pickers" % (len(groups), n, len(colors)))
    summarize(base, e.tree)
    print("wrote %s (%d bytes) and %s" % (OUT_CFG, len(data), OUT_JSON))


if __name__ == "__main__":
    main()
