import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPOS = HERE.parents[2]
ISAS = ("avx2", "avx512")
HEADER = re.compile(r"^[0-9a-fA-F]+ <(.+)>:$")
INSTRUCTION = re.compile(r"^\s*[0-9a-fA-F]+:\s+([a-z][a-z0-9.]*)\s*(.*)$")
NM_ROW = re.compile(r"^[0-9a-fA-F ]+ ([A-Za-z]) (.+)$")
EXTENSION_OPS = ("andn", "bextr", "blsi", "blsmsk", "blsr", "bzhi", "pdep", "pext", "mulx", "rorx", "sarx", "shlx", "shrx",
                 "tzcnt", "lzcnt", "popcnt", "pclmul", "kmov", "kand", "kor", "kxor", "knot", "kshift", "ktest", "kortest", "kunpck", "kadd")
WIDE_REGISTER = re.compile(r"\b%?(ymm|zmm)\d+\b|%k[0-7]\b|\bk[1-7]\b")


def find_tool(name):
    candidates = [name] + sorted(glob.glob(f"/usr/bin/{name}-*"), reverse=True)
    for root in ("C:/Program Files/Microsoft Visual Studio", "C:/Program Files (x86)/Microsoft Visual Studio"):
        candidates += sorted(glob.glob(f"{root}/*/*/VC/Tools/Llvm/x64/bin/{name}.exe"), reverse=True)
    for candidate in candidates:
        found = shutil.which(candidate) or (candidate if os.path.isfile(candidate) else None)
        if found:
            return found
    return None


def tools():
    objdump = find_tool("llvm-objdump") or find_tool("objdump")
    nm = find_tool("llvm-nm") or find_tool("nm")
    if not objdump or not nm:
        sys.exit("need llvm-objdump/objdump and llvm-nm/nm on PATH or in the Visual Studio Llvm folder")
    return objdump, nm


def external_code_symbols(nm, obj):
    text = subprocess.run([nm, "--defined-only", "-C", str(obj)], check=True, capture_output=True, text=True).stdout
    names = set()
    for line in text.splitlines():
        match = NM_ROW.match(line)
        if match and match.group(1) in "TW":
            names.add(match.group(2).strip())
    return names


def functions(objdump, obj):
    text = subprocess.run([objdump, "-d", "-C", "--no-show-raw-insn", str(obj)], check=True, capture_output=True, text=True).stdout
    current = None
    body = []
    for line in text.splitlines():
        header = HEADER.match(line.strip())
        if header:
            if current is not None:
                yield current, body
            current, body = header.group(1), []
            continue
        if current is not None:
            match = INSTRUCTION.match(line)
            if match:
                body.append((match.group(1), match.group(2)))
    if current is not None:
        yield current, body


def needs_extension(mnemonic, operands):
    if mnemonic.startswith("v") and mnemonic not in ("verr", "verw"):
        return True
    if mnemonic.startswith(EXTENSION_OPS):
        return True
    return bool(WIDE_REGISTER.search(operands))


def check(obj, isa, objdump, nm):
    markers = (f"jsonifier_{isa}", f"isa_{isa}")
    shared = {name for name in external_code_symbols(nm, obj) if not any(marker in name for marker in markers)}
    leaks = []
    for name, body in functions(objdump, obj):
        if name not in shared:
            continue
        hits = [f"{mnemonic} {operands}".strip() for mnemonic, operands in body if needs_extension(mnemonic, operands)]
        if hits:
            leaks.append((name, hits))
    print(f"{obj}: {len(shared)} shared code symbols outside the {isa} namespaces, {len(leaks)} using {isa}-only instructions")
    for name in sorted(shared):
        print(f"  {'LEAK ' if any(leak[0] == name for leak in leaks) else 'ok   '}{name}")
    for name, hits in leaks:
        print(f"  {name}: {', '.join(hits[:4])}{' ...' if len(hits) > 4 else ''}")
    return not leaks


def main():
    parser = argparse.ArgumentParser(description="Flag shared (weak/COMDAT) functions in Node's per-ISA Jsonifier objects that contain ISA-only instructions.")
    parser.add_argument("out_dir", nargs="?", default=str(REPOS / "node" / "out" / "Release"), help="node build output folder (default <repos>/node/out/Release)")
    args = parser.parse_args()
    objdump, nm = tools()
    clean = True
    found_any = False
    for isa in ISAS:
        for obj in sorted(Path(args.out_dir).rglob(f"package_json_parser_{isa}.o*")):
            if obj.suffix not in (".o", ".obj"):
                continue
            found_any = True
            clean &= check(obj, isa, objdump, nm)
    if not found_any:
        sys.exit(f"no package_json_parser_<isa> objects under {args.out_dir}")
    sys.exit(0 if clean else 1)


if __name__ == "__main__":
    main()
