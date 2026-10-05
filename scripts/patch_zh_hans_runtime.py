#!/usr/bin/env python3
"""Append the zh-Hans display layer to the generated V3 unified shell."""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BEGIN = "// V3_ZH_HANS_RUNTIME_V1_BEGIN"


def main(live: Path) -> None:
    shell = live / "LiveContainerSwiftUI/Views/V3UnifiedShell.swift"
    text = shell.read_text(encoding="utf-8")
    if BEGIN in text:
        print("zh-Hans runtime already present")
        return
    template = (HERE / "templates/v3_zh_hans_runtime.swift").read_text(encoding="utf-8")
    table = (HERE / "zh_hans_map.json").read_text(encoding="utf-8").strip()
    if '"""#' in table:
        raise SystemExit("translation table would terminate the raw string literal")
    block = template.replace("__V3ZH_JSON__", table)
    shell.write_text(text.rstrip("\n") + "\n\n" + block, encoding="utf-8")
    print(f"appended zh-Hans runtime ({len(table)} bytes of table) to {shell}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
