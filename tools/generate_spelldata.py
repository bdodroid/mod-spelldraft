#!/usr/bin/env python3
"""
Prerequisites:
  - Python 3.x
  - docker / podman compose running the ac-database container
  - Target path: wow-client/Interface/AddOns/SpellDraft/SpellData.lua

Usage:
  python3 tools/generate_spelldata.py
"""

import re
import subprocess
import os
import sys

# Define target paths
MODULE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURRENT_SPELLDATA_PATH = os.path.join(MODULE_ROOT, "wow-client/Interface/AddOns/SpellDraft/SpellData.lua")

# Connect and run MySQL query in ac-database container
def run_query(query):
    cmd = [
        "docker", "exec", "ac-database", "mysql",
        "-uroot", "-ppassword", "acore_world",
        "-e", query
    ]
    env = os.environ.copy()
    if "DOCKER_HOST" not in env:
        env["DOCKER_HOST"] = f"unix:///run/user/{os.getuid()}/podman/podman.sock"
    res = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error querying DB: {res.stderr}", file=sys.stderr)
        sys.exit(1)
    
    lines = res.stdout.strip().split("\n")
    if not lines or lines == ['']:
        return []
    
    headers = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) == len(headers):
            rows.append(dict(zip(headers, parts)))
    return rows

CLASS_SKILL_LINES = {
    # Mage
    6: "MAGE", 8: "MAGE", 237: "MAGE",
    # Warlock
    354: "WARLOCK", 355: "WARLOCK", 593: "WARLOCK", 188: "WARLOCK", 761: "WARLOCK",
    # Druid
    134: "DRUID", 574: "DRUID", 573: "DRUID",
    # Paladin
    594: "PALADIN", 267: "PALADIN", 184: "PALADIN",
    # Priest
    56: "PRIEST", 78: "PRIEST", 613: "PRIEST",
    # Shaman
    373: "SHAMAN", 375: "SHAMAN", 374: "SHAMAN",
    # Hunter
    51: "HUNTER", 163: "HUNTER", 50: "HUNTER", 270: "HUNTER", 788: "HUNTER",
    # Rogue
    39: "ROGUE", 38: "ROGUE", 253: "ROGUE", 633: "ROGUE",
    # Warrior
    256: "WARRIOR", 257: "WARRIOR", 26: "WARRIOR",
    # Death Knight
    770: "DEATHKNIGHT", 771: "DEATHKNIGHT", 772: "DEATHKNIGHT", 776: "DEATHKNIGHT", 782: "DEATHKNIGHT",
}

def determine_class(sl_list):
    for r in sl_list:
        sl_val = r["SkillLine"]
        sl_id = int(sl_val) if (sl_val and sl_val != 'NULL') else None
        sl_name = r["DisplayName_Lang_enUS"] if (r["DisplayName_Lang_enUS"] and r["DisplayName_Lang_enUS"] != 'NULL') else ""
        
        if sl_id in CLASS_SKILL_LINES:
            return CLASS_SKILL_LINES[sl_id]
            
        if sl_name.startswith("Pet - ") or sl_name.startswith("Pet-"):
            if any(w in sl_name for w in ["Imp", "Felhunter", "Voidwalker", "Succubus", "Infernal", "Doomguard", "Felguard"]):
                return "WARLOCK"
            elif "Ghoul" in sl_name:
                return "DEATHKNIGHT"
            else:
                return "HUNTER"
                
    return "GENERAL"

# Hand-maintained kit/basic spells the Grimoire must always list. These are
# granted alongside drafted spells (pet kits, form kits, auto attacks) but do
# not exist in dbc_spells with a rarity, so generation alone would drop them.
KIT_SPELLS = {
    75: {"rarity": 0, "class": "GENERAL", "name": "Auto Shot"},
    133: {"rarity": 0, "class": "MAGE", "name": "Fireball"},
    136: {"rarity": 0, "class": "HUNTER", "name": "Mend Pet"},
    168: {"rarity": 0, "class": "MAGE", "name": "Frost Armor"},
    883: {"rarity": 0, "class": "HUNTER", "name": "Call Pet"},
    982: {"rarity": 0, "class": "HUNTER", "name": "Revive Pet"},
    1082: {"rarity": 0, "class": "DRUID", "name": "Claw"},
    2641: {"rarity": 0, "class": "HUNTER", "name": "Dismiss Pet"},
    2764: {"rarity": 0, "class": "GENERAL", "name": "Throw"},
    5019: {"rarity": 0, "class": "GENERAL", "name": "Shoot"},
    6603: {"rarity": 0, "class": "GENERAL", "name": "Attack"},
    6991: {"rarity": 0, "class": "HUNTER", "name": "Feed Pet"},
    54785: {"rarity": 0, "class": "WARLOCK", "name": "Demon Charge"},
    59671: {"rarity": 0, "class": "WARLOCK", "name": "Challenging Howl"},
}


def main():
    # 1. Parse current SpellData.lua
    current_spells = {}
    if os.path.exists(CURRENT_SPELLDATA_PATH):
        with open(CURRENT_SPELLDATA_PATH, "r", encoding="utf-8") as f:
            for line in f:
                match = re.search(r"\[(\d+)\]\s*=\s*\{\s*rarity\s*=\s*(\d+),\s*class\s*=\s*\"([^\"]+)\",\s*name\s*=\s*\"([^\"]+)\"\s*\}", line)
                if match:
                    spell_id = int(match.group(1))
                    rarity = int(match.group(2))
                    cls = match.group(3)
                    name = match.group(4)
                    current_spells[spell_id] = {"rarity": rarity, "class": cls, "name": name}

    # 2. Query database for spells with Rarity IS NOT NULL
    print("Querying spells from server database...")
    db_spells_raw = run_query("""
        SELECT s.Id, s.Rarity, s.Name_Lang_enUS, sa.SkillLine, sl.DisplayName_Lang_enUS, sl.CategoryID
        FROM dbc_spells s
        LEFT JOIN dbc_skilllineability sa ON s.Id = sa.Spell
        LEFT JOIN dbc_skillline sl ON sa.SkillLine = sl.ID
        WHERE s.Rarity IS NOT NULL;
    """)

    # Group by spell Id
    db_spells = {}
    for row in db_spells_raw:
        sid = int(row["Id"])
        if sid not in db_spells:
            db_spells[sid] = {
                "id": sid,
                "rarity": int(row["Rarity"]),
                "name": row["Name_Lang_enUS"],
                "skill_lines": []
            }
        if row["SkillLine"]:
            db_spells[sid]["skill_lines"].append(row)

    # 3. Classify and escape names
    generated_spells = {}
    for sid, db_info in db_spells.items():
        derived_class = determine_class(db_info["skill_lines"])
        
        # Override class with existing if it exists in current SpellData.lua
        # (excluding known duplicates/stale cases handled by DB update)
        is_known_dupe = sid in [3276, 3277, 3278, 7928, 7929, 7934, 10840, 10841, 18629, 18630]
        if sid in current_spells and not is_known_dupe:
            final_class = current_spells[sid]["class"]
        else:
            final_class = derived_class
            
        final_rarity = db_info["rarity"]
        raw_name = db_info["name"]
        
        # Fix the escaping bug: replace backslashes before quotes
        clean_name = re.sub(r'\\+\'', "'", raw_name)
        # Escape backslashes and double quotes for double-quoted Lua string
        escaped_name = clean_name.replace('\\', '\\\\').replace('"', '\\"')
        
        generated_spells[sid] = {
            "rarity": final_rarity,
            "class": final_class,
            "name": escaped_name
        }

    # 4. Generate Diff summary
    added = []
    removed = []
    changed = []

    for sid in generated_spells:
        if sid not in current_spells:
            added.append(sid)
        elif current_spells[sid]["class"] != generated_spells[sid]["class"] or current_spells[sid]["rarity"] != generated_spells[sid]["rarity"] or current_spells[sid]["name"] != generated_spells[sid]["name"]:
            changed.append(sid)

    for sid in current_spells:
        if sid not in generated_spells:
            removed.append(sid)

    for sid, info in KIT_SPELLS.items():
        if sid not in generated_spells:
            generated_spells[sid] = dict(info)

    print(f"Diff Summary:")
    print(f"  Added spells: {len(added)}")
    print(f"  Removed spells (stale): {len(removed)} (IDs: {removed})")
    print(f"  Changed spells: {len(changed)} (IDs: {changed})")

    # 5. Write to SpellData.lua
    with open(CURRENT_SPELLDATA_PATH, "w", encoding="utf-8") as f:
        f.write("-- Auto-generated Spell Draft Database for the custom Spellbook UI\n")
        f.write("SpellDraftData = {\n")
        for sid in sorted(generated_spells.keys()):
            info = generated_spells[sid]
            f.write(f'  [{sid}] = {{ rarity = {info["rarity"]}, class = "{info["class"]}", name = "{info["name"]}" }},\n')
        f.write("}\n")
    
    print(f"Regenerated database written to {CURRENT_SPELLDATA_PATH}")

if __name__ == "__main__":
    main()
