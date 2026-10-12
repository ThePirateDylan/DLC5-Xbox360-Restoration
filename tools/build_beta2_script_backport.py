#!/usr/bin/env python3
"""Build a test-only, no-extra-loader GSC/CSC backport into existing BO2 scripts.

This tool only edits a copied unpacked FastFile under local-input. It never edits
the input FastFile, input scan, or the Aurora staging directory. New Beta 2 script
functions are namespaced and folded into existing ScriptParseTree assets, then
started from the stock Zombies GSC/CSC init entrypoints.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


BLOCKED_APIS = ("getfunction", "replacefunc", "setwaterdrops", "setworldfogactivebank")
EXCLUDED_FILES = {
    # Prototype-only content is outside the requested DLC5 maps.
    "zzz_protoround.gsc": "prototype-only",
    "zzz_zm_location.gsc": "prototype-only",
    "zzz_zm_barrelsound.gsc": "prototype-only",
    # Diagnostic probes/watchers are not gameplay fixes.
    "zzz_zm_cscprobe.csc": "diagnostic probe",
    "zzz_zm_crawlerwatch.gsc": "diagnostic probe",
    "zzz_zm_centrifugewatch.gsc": "diagnostic probe",
    "zzz_zm_gravitywatch.gsc": "diagnostic probe",
    "zzz_zm_whereami.gsc": "diagnostic probe",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compile_source(text: str, basename: str, instance: str, tool: Path, temp_root: Path) -> bytes:
    with tempfile.TemporaryDirectory(prefix="gsc-build-", dir=temp_root) as temp:
        temp_path = Path(temp)
        source = temp_path / basename
        source.write_text(text, encoding="utf-8", newline="\n")
        result = subprocess.run(
            [str(tool), "-m", "comp", "-g", "t6", "-s", "xb2", "-i", instance, str(source)],
            cwd=temp_path,
            capture_output=True,
            text=True,
            timeout=600,
        )
        if result.returncode:
            detail = (result.stderr or result.stdout).strip()
            raise RuntimeError(f"gsc-tool failed for {basename}: {detail[:1600]}")
        output = temp_path / "compiled" / "t6" / basename
        if not output.is_file():
            raise RuntimeError(f"gsc-tool did not create {output}")
        payload = output.read_bytes()
        if not payload.startswith(b"\x80GSC"):
            raise RuntimeError(f"compiled payload for {basename} has no T6 GSC header")
        return payload


def top_level_functions(source: str) -> list[str]:
    # The Beta 2 inputs in this set use one top-level function per declaration
    # line, with no nested function definitions.
    return re.findall(r"(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*\([^\n]*\)\s*(?=\{)", source)


def apply_static_compatibility(filename: str, text: str) -> tuple[str, list[str]]:
    """Replace selected Plutonium function lookups with stock qualified calls."""
    rewrites: list[str] = []

    def sub_once(pattern: str, replacement: str, label: str, flags: int = re.MULTILINE) -> None:
        nonlocal text
        text_new, count = re.subn(pattern, lambda _match: replacement, text, count=1, flags=flags)
        if count != 1:
            raise RuntimeError(f"expected one {label} compatibility pattern in {filename}; found {count}")
        text = text_new
        rewrites.append(label)

    if filename == "zzz_zm_boxstart.gsc":
        sub_once(
            r'\tf = getfunction\( "maps/mp/zombies/_zm_magicbox", "init_starting_chest_location" \);.*?\n\t\[\[ f \]\]\( "start_chest" \);',
            'maps\\mp\\zombies\\_zm_magicbox::init_starting_chest_location( "start_chest" );',
            "static _zm_magicbox::init_starting_chest_location call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_factorymine.gsc":
        sub_once(
            r'\treg = getfunction\( "maps/mp/zombies/_zm_utility", "register_placeable_mine_for_level" \);.*?\n\tprintln\( "FACTORYMINE >> claymore_zm registered',
            'maps\\mp\\zombies\\_zm_utility::register_placeable_mine_for_level( "claymore_zm" );\n\tprintln( "FACTORYMINE >> claymore_zm registered',
            "static placeable-mine registration call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_templefall.gsc":
        sub_once(
            r'\treg = getfunction\( "maps/mp/zombies/_zm", "register_player_damage_callback" \);.*?\n\tprintln\( "TEMPLEFALL >> armed',
            'maps\\mp\\zombies\\_zm::register_player_damage_callback( ::templefall_damage );\n\tprintln( "TEMPLEFALL >> armed',
            "static damage-callback registration call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_h2_preserve.gsc":
        sub_once(
            r'\tfp = GetFunction\( "maps/mp/zombies/_zm_utility", "get_round_enemy_array" \);.*?\n\tprintln\( "H2PRESERVE >> armed" \);',
            '\tprintln( "H2PRESERVE >> armed" );',
            "static round-enemy-array lookup",
            re.DOTALL,
        )
        if "zombies = [[ fp ]]();" not in text:
            raise RuntimeError(f"dynamic get_round_enemy_array call not found in {filename}")
        text = text.replace("zombies = [[ fp ]]();", "zombies = maps\\mp\\zombies\\_zm_utility::get_round_enemy_array();", 1)
        rewrites.append("direct _zm_utility::get_round_enemy_array call")
    elif filename == "zzz_zm_nmlsprint.gsc":
        sub_once(
            r'\tfp = GetFunction\( "maps/mp/zombies/_zm_utility", "get_round_enemy_array" \);.*?\n\trearmed = 0;',
            '\tprintln( "NMLSPRINT >> armed (stock static calls)" );\n\trearmed = 0;',
            "static sprint helper lookups",
            re.DOTALL,
        )
        if "zombies = [[ fp ]]();" not in text:
            raise RuntimeError(f"dynamic get_round_enemy_array call not found in {filename}")
        text = text.replace("zombies = [[ fp ]]();", "zombies = maps\\mp\\zombies\\_zm_utility::get_round_enemy_array();", 1)
        sub_once(
            r'\t+if \( isdefined\( fp_set \) \)\s*\{.*?\}\s*else\s*\{.*?\}',
            'z maps\\mp\\zombies\\_zm_utility::set_zombie_run_cycle( "super_sprint" );',
            "static set_zombie_run_cycle method call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_sumpfriser.gsc":
        sub_once(
            r'\telse\n\t\{\n\t\tlevel\.r9retail = getfunction\( "maps/mp/zombies/_zm_zonemgr", "create_spawner_list" \);\n\t\}',
            '\telse\n\t{\n\t\tlevel.r9retail = maps\\mp\\zombies\\_zm_zonemgr::create_spawner_list;\n\t}',
            "static create_spawner_list function pointer",
        )
    elif filename == "zzz_zm_moonroundhud.gsc":
        sub_once(
            r'\tfp_music = GetFunction\( "maps/mp/zombies/_zm_audio", "change_zombie_music" \);\n',
            "",
            "static music helper lookup",
        )
        sub_once(
            r'\t+if \( isdefined\( fp_music \) \)\s*\{.*?\}\s*else\s*\{.*?\}',
            '\t\t\t\t\tlevel thread maps\\mp\\zombies\\_zm_audio::change_zombie_music( "round_start" );\n\t\t\t\t\tprintln( "MOONROUNDHUD >> sting fired" );',
            "static change_zombie_music call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_sumpfperkvo.gsc":
        sub_once(
            r'\tfd = GetFunction\( "maps/mp/zombies/_zm_audio", "create_and_play_dialog" \);.*?\n\t\}\n\telse\n\t\{.*?\n\t\}',
            '\tbest maps\\mp\\zombies\\_zm_audio::create_and_play_dialog( "level", key );\n\tprintln( "PERKVO >> " + key + " reveal line played (dist " + int( bestd ) + ")" );',
            "static create_and_play_dialog method call",
            re.DOTALL,
        )
    elif filename == "zzz_zm_bowiebuy.gsc":
        sub_once(
            r'players\[ i \] thread \[\[ getfunction\( "maps/mp/zombies/_zm_audio", "create_and_play_dialog" \) \]\]\( "weapon_pickup", "bowie" \);',
            'players[ i ] thread maps\\mp\\zombies\\_zm_audio::create_and_play_dialog( "weapon_pickup", "bowie" );',
            "static create_and_play_dialog thread call",
        )
    elif filename == "zzz_zm_templesemtex.gsc":
        sub_once(
            r'\tinc = getfunction\( "maps/mp/zombies/_zm_utility", "include_weapon" \);.*?\n\tlevel thread templesemtex_apply\(\);',
            '\tmaps\\mp\\zombies\\_zm_utility::include_weapon( "sticky_grenade_zm", false );\n\tprintln( "TEMPLESEMTEX >> include_weapon(sticky_grenade_zm, false) called" );\n\tmaps\\mp\\zombies\\_zm_weapons::add_zombie_weapon( "sticky_grenade_zm", undefined, &"ZOMBIE_WEAPON_STICKY_GRENADE", 250, "grenade", "", 250 );\n\tprintln( "TEMPLESEMTEX >> add_zombie_weapon(sticky_grenade_zm) 250" );\n\tlevel thread templesemtex_apply();',
            "static sticky-grenade registration calls",
            re.DOTALL,
        )
        sub_once(
            r'\treg = getfunction\( "maps/mp/zombies/_zm_utility", "register_lethal_grenade_for_level" \);.*?\n\tprintln\( "TEMPLESEMTEX >> sticky_grenade_zm registered',
            '\tmaps\\mp\\zombies\\_zm_utility::register_lethal_grenade_for_level( "sticky_grenade_zm" );\n\tprintln( "TEMPLESEMTEX >> sticky_grenade_zm registered',
            "static lethal-grenade registration call",
            re.DOTALL,
        )
        sub_once(
            r'\trw = getfunction\( "maps/mp/zombies/_zm_weapons", "reset_wallbuys" \);.*?\n\tprintln\( "TEMPLESEMTEX >> armed after',
            '\tmaps\\mp\\zombies\\_zm_weapons::reset_wallbuys();\n\tprintln( "TEMPLESEMTEX >> armed after',
            "static wall-buy reset call",
            re.DOTALL,
        )
    elif filename == "zzz_zz_zzzzzzzztemplespecials.gsc":
        sub_once(
            r'\tfd = GetFunction\( "maps/mp/zombies/_zm_audio", "create_and_play_dialog" \);\s*if \( !isdefined\( fd \) \)\s*\{.*?\}\s*players = getplayers\(\);',
            '\tplayers = getplayers();',
            "static Shangri-La callout helper lookup",
            re.DOTALL,
        )
        sub_once(
            r'p thread \[\[ fd \]\]\( "general", key \);',
            'p thread maps\\mp\\zombies\\_zm_audio::create_and_play_dialog( "general", key );',
            "static Shangri-La callout thread",
        )
    elif filename in ("zm_dog_combat.gsc", "zm_dog_stop.gsc"):
        pattern = re.compile(
            r'\bgetfunction\s*\(\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\s*\)',
            re.IGNORECASE,
        )

        def static_function_reference(match: re.Match[str]) -> str:
            script = match.group(1).replace("/", "\\")
            function = match.group(2)
            return script + "::" + function

        text, count = pattern.subn(static_function_reference, text)
        if count == 0:
            raise RuntimeError(f"no literal GetFunction calls found in {filename}")
        rewrites.append(f"{count} static animation-script function references")
    else:
        return text, rewrites
    return text, rewrites


def namespace_module(source: Path, input_text: str | None = None) -> tuple[str, str]:
    text = input_text if input_text is not None else source.read_text(encoding="utf-8", errors="replace")
    if re.search(r"(?im)^\s*#\s*include\b", text):
        raise RuntimeError(f"unexpected include directive in {source.name}; refusing an unsafe merge")
    functions = top_level_functions(text)
    if not functions:
        raise RuntimeError(f"no top-level GSC functions found in {source.name}")
    if "init" not in functions:
        raise RuntimeError(f"no init() entrypoint in {source.name}")
    prefix = "dlc5_" + source.stem.lower() + "_"
    replacements = {name: prefix + name.lower() for name in functions}
    pattern = re.compile(r"\b(" + "|".join(re.escape(n) for n in sorted(functions, key=len, reverse=True)) + r")\b")
    text = pattern.sub(lambda m: replacements[m.group(1)], text)
    return text.strip(), replacements["init"]


def matching_function_end(source: str, function_name: str) -> int:
    match = re.search(r"(?m)^" + re.escape(function_name) + r"\s*\([^\n]*\)\s*\{", source)
    if not match:
        raise RuntimeError(f"could not find {function_name}() in host script")
    depth = 1
    i = match.end()
    state = "code"
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if state == "string":
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                state = "code"
        elif state == "line":
            if ch == "\n":
                state = "code"
        elif state == "block":
            if ch == "*" and nxt == "/":
                state = "code"
                i += 2
                continue
        elif state == "slashblock":
            if ch == "#" and nxt == "/":
                state = "code"
                i += 2
                continue
        elif state == "code":
            if ch == '"':
                state = "string"
            elif ch == "/" and nxt == "/":
                state = "line"
                i += 2
                continue
            elif ch == "/" and nxt == "*":
                state = "block"
                i += 2
                continue
            elif ch == "/" and nxt == "#":
                state = "slashblock"
                i += 2
                continue
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    raise RuntimeError(f"unterminated {function_name}() body")


def remove_function_definition(source: str, function_name: str) -> str:
    match = re.search(r"(?m)^" + re.escape(function_name) + r"\s*\([^\n]*\)\s*\{", source)
    if not match:
        return source
    end = matching_function_end(source, function_name)
    return source[:match.start()] + source[end + 1:]


def append_call_to_function(source: str, function_name: str, call: str) -> str:
    end = matching_function_end(source, function_name)
    return source[:end].rstrip() + "\n    " + call + "\n" + source[end:]


def path_as_gsc(script_name: str) -> str:
    return script_name.rsplit(".", 1)[0].replace("/", "\\")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, required=True, help="unpacked patch_zm scan with scripts_src/ and zone_decompressed.dat")
    parser.add_argument("--sources", type=Path, required=True, help="local Beta 2 script source folder")
    parser.add_argument("--xbox-overrides", type=Path, help="optional folder of Xbox-compatible replacements for source files")
    parser.add_argument("--gsc-tool", type=Path, required=True, help="gsc-tool executable")
    parser.add_argument("--unpacker", type=Path, required=True, help="Crybaby xbox360_ff_unpacker.py")
    parser.add_argument("--out-scan", type=Path, required=True, help="new, non-existing copied scan output under local-input")
    parser.add_argument("--out-ff", type=Path, required=True, help="new, non-existing test FastFile output under local-input")
    parser.add_argument("--verify-dir", type=Path, required=True, help="new, non-existing candidate decode output under local-input")
    parser.add_argument("--reserve", type=int, default=768, help="bytes reserved in each script slot for dispatcher overhead")
    args = parser.parse_args()

    root = Path.cwd()
    scan = args.scan.resolve()
    sources = args.sources.resolve()
    xbox_overrides = args.xbox_overrides.resolve() if args.xbox_overrides else None
    tool = args.gsc_tool.resolve()
    unpacker = args.unpacker.resolve()
    out_scan = args.out_scan.resolve()
    out_ff = args.out_ff.resolve()
    verify_dir = args.verify_dir.resolve()
    temp_root = (root / "local-input" / "crybaby-test" / "tmp").resolve()
    temp_root.mkdir(parents=True, exist_ok=True)

    for path in (scan, sources, tool, unpacker):
        if not path.exists():
            raise FileNotFoundError(path)
    for path in (out_scan, out_ff, verify_dir):
        if path.exists():
            raise FileExistsError(f"refusing to overwrite existing output: {path}")
    if not args.out_scan.resolve().is_relative_to((root / "local-input").resolve()):
        raise RuntimeError("--out-scan must stay under local-input")
    if not args.out_ff.resolve().is_relative_to((root / "local-input").resolve()):
        raise RuntimeError("--out-ff must stay under local-input")
    if not args.verify_dir.resolve().is_relative_to((root / "local-input").resolve()):
        raise RuntimeError("--verify-dir must stay under local-input")

    metadata_path = scan / "embedded_scripts.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    records = {record["script_name"]: record for record in metadata["scripts"]}

    include: list[dict] = []
    excluded: dict[str, str] = {}
    api_pattern = re.compile(r"\b(" + "|".join(BLOCKED_APIS) + r")\b", re.IGNORECASE)
    for module_path in sorted(sources.iterdir()):
        if module_path.suffix.lower() not in (".gsc", ".csc"):
            continue
        if module_path.name in EXCLUDED_FILES:
            excluded[module_path.name] = EXCLUDED_FILES[module_path.name]
            continue
        effective_path = xbox_overrides / module_path.name if xbox_overrides and (xbox_overrides / module_path.name).is_file() else module_path
        original = effective_path.read_text(encoding="utf-8", errors="replace")
        original, static_rewrites = apply_static_compatibility(module_path.name, original)
        api = api_pattern.search(original)
        if api:
            excluded[module_path.name] = f"requires non-stock API: {api.group(1)}"
            continue
        try:
            merged_text, init_name = namespace_module(effective_path, original)
        except RuntimeError as error:
            excluded[module_path.name] = str(error)
            continue
        instance = "client" if module_path.suffix.lower() == ".csc" else "server"
        payload = compile_source(merged_text, module_path.name, instance, tool, temp_root)
        include.append({
            "name": module_path.name,
            "source_path": str(effective_path),
            "static_compatibility_rewrites": static_rewrites,
            "instance": instance,
            "merged": merged_text,
            "init": init_name,
            "estimated_bytes": len(payload),
        })

    if not include:
        raise RuntimeError("no compatible Beta 2 script modules were found")
    has_ambflies_module = any(module["name"] == "zzz_zm_ambflies.gsc" for module in include)

    # Compile stock source scripts to find actual safe payload headroom. The
    # current scan may already contain the ambient-flies experiment in utility;
    # that is included in this baseline and will not be overwritten.
    hosts: dict[str, dict] = {}
    for script_name, record in records.items():
        if record.get("instance") not in ("server", "client"):
            continue
        rel = Path(script_name)
        host_path = scan / "scripts_src" / rel
        if not host_path.is_file():
            continue
        base_text = host_path.read_text(encoding="utf-8", errors="replace")
        if script_name == "maps/mp/zombies/_zm_utility.gsc" and has_ambflies_module:
            for function_name in ("dlc5_ambflies_init", "dlc5_ambflies_arm", "dlc5_ambflies_emit"):
                base_text = remove_function_definition(base_text, function_name)
        base_payload = compile_source(base_text, rel.name, record["instance"], tool, temp_root)
        slack = record["payload_size"] - len(base_payload)
        if slack > args.reserve:
            hosts[script_name] = {
                "record": record,
                "base": base_text,
                "slack": slack,
                "instance": record["instance"],
                "modules": [],
                "estimated_used": 0,
            }

    bins: dict[str, dict] = {}
    server_modules = [module for module in include if module["instance"] == "server"]
    client_modules = [module for module in include if module["instance"] == "client"]
    for module in sorted(server_modules, key=lambda m: m["estimated_bytes"], reverse=True):
        candidates = sorted(
            (
                name for name, host in hosts.items()
                if host["instance"] == module["instance"]
                and host["slack"] - args.reserve - host["estimated_used"] >= module["estimated_bytes"]
            ),
            key=lambda name: hosts[name]["slack"] - args.reserve - hosts[name]["estimated_used"],
            reverse=True,
        )
        chosen = candidates[0] if candidates else None
        if chosen is None:
            raise RuntimeError(f"no existing {module['instance']} script slot has room for {module['name']} ({module['estimated_bytes']} bytes)")
        hosts[chosen]["modules"].append(module)
        hosts[chosen]["estimated_used"] += module["estimated_bytes"]
        bins[chosen] = hosts[chosen]

    if "maps/mp/zombies/_zm_devgui.gsc" not in bins:
        # Keep the always-loaded dispatcher in the existing script with the most
        # spare room. It is still only reached via the stock _zm init path.
        server_bins = [name for name, host in bins.items() if host["instance"] == "server"]
        dispatcher_host = max(server_bins, key=lambda name: hosts[name]["slack"])
    else:
        dispatcher_host = "maps/mp/zombies/_zm_devgui.gsc"
    if hosts[dispatcher_host]["instance"] != "server":
        raise RuntimeError("server dispatcher was assigned to a client script")

    shutil.copytree(scan, out_scan)
    output_zone = bytearray((out_scan / "zone_decompressed.dat").read_bytes())
    original_zone = (scan / "zone_decompressed.dat").read_bytes()
    baseline_payloads: dict[str, bytes] = {}
    compiled_payloads: dict[str, bytes] = {}
    edited_sources: dict[str, str] = {}

    # Prepare the stock server entrypoint before composing hosts: _zm.gsc can
    # itself be selected as a module host, so its startup call must survive that
    # merge instead of being overwritten by the unmodified host source.
    zm_name = "maps/mp/zombies/_zm.gsc"
    if zm_name not in records:
        raise RuntimeError("patch_zm scan is missing the stock Zombies _zm.gsc entrypoint")
    zm_host = scan / "scripts_src" / Path(zm_name)
    zm_text = zm_host.read_text(encoding="utf-8", errors="replace")
    zm_text = append_call_to_function(zm_text, "init", f"{path_as_gsc(dispatcher_host)}::dlc5_beta2_dispatch_init();")
    edited_sources[zm_name] = zm_text
    baseline_payloads[zm_name] = original_zone[
        records[zm_name]["payload_offset"]:records[zm_name]["payload_offset"] + records[zm_name]["payload_size"]
    ]

    host_dispatch_names: dict[str, str] = {}
    for script_name, host in bins.items():
        host_base = zm_text if script_name == zm_name else host["base"]
        merged = host_base.rstrip() + "\n\n// DLC5 Beta 2 modules folded into this stock ScriptParseTree asset.\n"
        for module in host["modules"]:
            merged += "\n// Source: " + module["name"] + "\n" + module["merged"] + "\n"
        dispatch_name = "dlc5_beta2_local_dispatch"
        calls = "\n".join(f"    {module['init']}();" for module in host["modules"])
        merged += f"\n{dispatch_name}()\n{{\n{calls}\n}}\n"
        host["merged_source"] = merged
        host_dispatch_names[script_name] = dispatch_name

    # Add one public server dispatcher to the chosen host. It calls the local
    # module bundles and the ambient-flies routine already in _zm_utility.
    dispatcher = hosts[dispatcher_host]
    public_calls = []
    if not has_ambflies_module and "maps/mp/zombies/_zm_utility.gsc" in records:
        utility_record = records["maps/mp/zombies/_zm_utility.gsc"]
        utility_blob = original_zone[utility_record["payload_offset"]:utility_record["payload_offset"] + utility_record["payload_size"]]
        if b"dlc5_ambflies_init" in utility_blob:
            public_calls.append("    maps\\mp\\zombies\\_zm_utility::dlc5_ambflies_init();")
    for host_name in bins:
        dispatch_call = host_dispatch_names[host_name] + "()" if host_name == dispatcher_host else f"{path_as_gsc(host_name)}::{host_dispatch_names[host_name]}()"
        public_calls.append("    " + dispatch_call + ";")
    dispatcher["merged_source"] += "\ndlc5_beta2_dispatch_init()\n{\n" + "\n".join(public_calls) + "\n}\n"

    for host_name, host in bins.items():
        edited_sources[host_name] = host["merged_source"]
        baseline_payloads[host_name] = original_zone[
            host["record"]["payload_offset"]:host["record"]["payload_offset"] + host["record"]["payload_size"]
        ]
        compiled_payloads[host_name] = compile_source(
            host["merged_source"], Path(host_name).name, host["instance"], tool, temp_root
        )
    if zm_name not in bins:
        compiled_payloads[zm_name] = compile_source(zm_text, Path(zm_name).name, "server", tool, temp_root)

    # Client-script modules use the same no-loader pattern, with the stock
    # clientscripts/mp/zombies/_zm.csc init as their bootstrapping point.
    client_host_name = "clientscripts/mp/zombies/_face_utility_zm.csc"
    if client_modules:
        if client_host_name not in records:
            raise RuntimeError("patch_zm scan is missing the client utility host script")
        client_host_path = scan / "scripts_src" / Path(client_host_name)
        client_host = client_host_path.read_text(encoding="utf-8", errors="replace").rstrip()
        client_host += "\n\n// DLC5 Beta 2 client modules folded into this stock ScriptParseTree asset.\n"
        for module in client_modules:
            client_host += "\n// Source: " + module["name"] + "\n" + module["merged"] + "\n"
        client_calls = "\n".join(f"    {module['init']}();" for module in client_modules)
        client_host += "\ndlc5_beta2_client_dispatch()\n{\n" + client_calls + "\n}\n"
        edited_sources[client_host_name] = client_host
        client_record = records[client_host_name]
        base_client = compile_source(
            (scan / "scripts_src" / Path(client_host_name)).read_text(encoding="utf-8", errors="replace"),
            Path(client_host_name).name,
            "client",
            tool,
            temp_root,
        )
        if len(client_host.encode("utf-8")) > 10_000_000:
            raise RuntimeError("client source unexpectedly large")
        compiled_payloads[client_host_name] = compile_source(client_host, Path(client_host_name).name, "client", tool, temp_root)
        baseline_payloads[client_host_name] = original_zone[
            client_record["payload_offset"]:client_record["payload_offset"] + client_record["payload_size"]
        ]
        client_slack = client_record["payload_size"] - len(base_client)
        if len(compiled_payloads[client_host_name]) > client_record["payload_size"]:
            raise RuntimeError(
                f"client modules overflow {client_host_name}: {len(compiled_payloads[client_host_name])} > {client_record['payload_size']} (headroom {client_slack})"
            )
        client_zm_name = "clientscripts/mp/zombies/_zm.csc"
        client_zm_path = scan / "scripts_src" / Path(client_zm_name)
        client_zm_text = client_zm_path.read_text(encoding="utf-8", errors="replace")
        client_zm_text = append_call_to_function(
            client_zm_text,
            "init",
            "clientscripts\\mp\\zombies\\_face_utility_zm::dlc5_beta2_client_dispatch();",
        )
        edited_sources[client_zm_name] = client_zm_text
        client_zm_record = records[client_zm_name]
        baseline_payloads[client_zm_name] = original_zone[
            client_zm_record["payload_offset"]:client_zm_record["payload_offset"] + client_zm_record["payload_size"]
        ]
        compiled_payloads[client_zm_name] = compile_source(
            client_zm_text, Path(client_zm_name).name, "client", tool, temp_root
        )

    # All edits are fit-only: existing payload allocations and every neighboring
    # FastFile offset remain fixed.
    fit_report = {}
    changed = set(compiled_payloads)
    for script_name in sorted(changed):
        record = records[script_name]
        payload = compiled_payloads[script_name]
        size = record["payload_size"]
        if len(payload) > size:
            raise RuntimeError(f"script slot overflow for {script_name}: {len(payload)} > {size}")
        start = record["payload_offset"]
        end = start + size
        if output_zone[start:start + 4] != b"\x80GSC":
            raise RuntimeError(f"original payload magic missing for {script_name}")
        output_zone[start:end] = payload + b"\0" * (size - len(payload))
        fit_report[script_name] = {
            "slot_bytes": size,
            "compiled_bytes": len(payload),
            "remaining_bytes": size - len(payload),
        }

    # Keep the generated source view in sync with the compiled bytes for audit
    # and reproducibility; the copied input scan remains untouched.
    for script_name, source_text in edited_sources.items():
        source_path = out_scan / "scripts_src" / Path(script_name)
        source_path.parent.mkdir(parents=True, exist_ok=True)
        source_path.write_text(source_text, encoding="utf-8", newline="\n")
        records[script_name]["source_path"] = str(source_path)
        records[script_name]["source_sha256"] = sha256(source_text.encode("utf-8"))
    (out_scan / "embedded_scripts.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )

    # Validate newly introduced qualified imports against the rebuilt shared
    # zone's script table before repacking.
    sys.path.insert(0, str(unpacker.parent))
    import gsc_link  # type: ignore

    (out_scan / "zone_decompressed.dat").write_bytes(output_zone)
    index = gsc_link.index_scripts([out_scan])
    link_reports = {}
    all_builtins: set[str] = set()
    for script_name in sorted(changed):
        parsed_old = baseline_payloads[script_name]
        report = gsc_link.regression(parsed_old, compiled_payloads[script_name], index)
        link_reports[script_name] = report
        all_builtins.update(report["builtins"])
        if report["missing"] or report["arity"]:
            lines = gsc_link.describe(report, script_name)
            raise RuntimeError("static GSC link regression:\n" + "\n".join(lines))

    # Re-parse all edited outputs and make sure each entrypoint is present.
    for script_name, payload in compiled_payloads.items():
        parsed = gsc_link.parse(payload)
        if not parsed:
            raise RuntimeError(f"cannot parse rebuilt script {script_name}")
    if b"dlc5_beta2_dispatch_init" not in compiled_payloads[dispatcher_host]:
        raise RuntimeError("server dispatcher was not compiled into its host")

    module_hosts = {
        module["name"]: host_name
        for host_name, host in bins.items()
        for module in host["modules"]
    }
    for module in client_modules:
        module_hosts[module["name"]] = client_host_name

    out_scan.mkdir(parents=True, exist_ok=True)
    manifest = {
        "purpose": "test-only script backport; not a console-verified package",
        "scan_input": str(scan),
        "source_input": str(sources),
        "included_modules": [module["name"] for module in include],
        "included_module_details": [
            {
                "name": module["name"],
                "instance": module["instance"],
                "host_script": module_hosts[module["name"]],
                "static_compatibility_rewrites": module["static_compatibility_rewrites"],
            }
            for module in include
        ],
        "excluded_modules": excluded,
        "modified_sources": sorted(edited_sources),
        "server_dispatcher_host": dispatcher_host,
        "server_host_assignments": {name: [m["name"] for m in host["modules"]] for name, host in bins.items()},
        "client_dispatcher_host": client_host_name if client_modules else None,
        "fit_report": fit_report,
        "new_unqualified_imports_to_verify_in_XEX": sorted(all_builtins),
        "link_reports": link_reports,
        "zone_sha256": sha256(bytes(output_zone)),
    }
    (out_scan / "beta2_script_backport_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    # Repack only to a new path and immediately decode it back for a byte-exact
    # zone comparison. The generated TAffu100 signature slot is intentionally
    # unsigned; the patched XEX/console must still be proven to accept it.
    result = subprocess.run(
        [sys.executable, str(unpacker), "--repack", str(out_scan), "--no-recompile", "--compression", "deflate", "-o", str(out_ff)],
        cwd=root,
        capture_output=True,
        text=True,
        env={**os.environ, "TEMP": str(temp_root), "TMP": str(temp_root)},
        timeout=900,
    )
    if result.returncode:
        raise RuntimeError("FastFile repack failed: " + (result.stderr or result.stdout)[-3000:])
    verify_dir.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [sys.executable, str(unpacker), str(out_ff), "-o", str(verify_dir), "--decompress-zone", "--no-decrypt-probe"],
        cwd=root,
        capture_output=True,
        text=True,
        env={**os.environ, "TEMP": str(temp_root), "TMP": str(temp_root)},
        timeout=900,
    )
    if result.returncode:
        raise RuntimeError("candidate FastFile decode verification failed: " + (result.stderr or result.stdout)[-3000:])
    decoded_zone = (verify_dir / "zone_decompressed.dat").read_bytes()
    if decoded_zone != bytes(output_zone):
        raise RuntimeError("candidate FastFile did not round-trip byte-exactly")

    manifest["candidate_fastfile"] = str(out_ff)
    manifest["candidate_bytes"] = out_ff.stat().st_size
    manifest["candidate_sha256"] = sha256(out_ff.read_bytes())
    manifest["roundtrip_zone_sha256"] = sha256(decoded_zone)
    manifest["roundtrip_exact"] = True
    (out_scan / "beta2_script_backport_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    changed_assets = len(changed)
    print(f"Integrated {len(include)} compatible Beta 2 script modules into {changed_assets} existing script assets.")
    print(f"Server dispatcher: {dispatcher_host} -> stock maps/mp/zombies/_zm.gsc init()")
    if client_modules:
        print(f"Client dispatcher: {client_host_name} -> stock clientscripts/mp/zombies/_zm.csc init()")
    print(f"Skipped {len(excluded)} module(s); reasons are recorded in the local manifest.")
    print(f"FastFile: {out_ff} ({out_ff.stat().st_size} bytes, SHA-256 {manifest['candidate_sha256']})")
    print(f"Exact decode round trip: {manifest['roundtrip_zone_sha256']}")
    if all_builtins:
        print("New unqualified engine imports to verify against this XEX: " + ", ".join(sorted(all_builtins)))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
