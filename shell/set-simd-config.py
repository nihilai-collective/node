import re
import sys


def main():
    source, target, isa, pod, blocks = sys.argv[1:6]
    marker = f"JSONIFIER_{isa}"
    lines = open(source, encoding="utf-8").read().split("\n")
    inside = False
    changed = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(("#if", "#elif", "#else", "#endif")):
            inside = stripped.startswith(("#if", "#elif")) and stripped.split()[1] == marker
            continue
        if inside:
            updated = re.sub(r"(smallDocumentBytes\{ )\d+", r"\g<1>" + pod, line)
            updated = re.sub(r"(simdBlocksPerStep\{ )\d+", r"\g<1>" + blocks, updated)
            changed += updated != line
            lines[index] = updated
    if changed == 0:
        raise SystemExit(f"set-simd-config: no {marker} smallDocumentBytes or simdBlocksPerStep lines in {source}")
    open(target, "w", encoding="utf-8", newline="").write("\n".join(lines))


if __name__ == "__main__":
    main()
