"""Busca código sin uso en GDScript: funciones sin llamadas, señales sin oyentes y constantes o variables sin leer.

Uso: python3 tools/find_unused.py src tests
Sale con código 1 si encuentra algo, para que el CI falle.
"""

import re
import sys
from pathlib import Path

ENGINE_CALLBACKS = {
    "_init", "_ready", "_process", "_physics_process", "_input", "_unhandled_input",
    "_enter_tree", "_exit_tree", "_initialize", "_notification", "_integrate_forces",
}
TEST_HOOKS = {"before_each", "after_each"}
TEST_PREFIX = "test_"

FUNC_PATTERN = re.compile(r"^(?:static\s+)?func\s+(\w+)", re.MULTILINE)
SIGNAL_PATTERN = re.compile(r"^signal\s+(\w+)", re.MULTILINE)
MEMBER_PATTERN = re.compile(r"^(?:@export\S*\s+|@onready\s+)*(?:const|var)\s+(\w+)", re.MULTILINE)


def collect_sources(roots):
    """Devuelve el texto de cada archivo .gd y .tscn bajo las carpetas indicadas."""
    sources = {}
    for root in roots:
        for path in Path(root).rglob("*"):
            if path.suffix in (".gd", ".tscn"):
                sources[path] = path.read_text(encoding="utf-8")
    return sources


def count_references(name, sources):
    """Cuenta las apariciones de un nombre como palabra completa en todos los archivos."""
    pattern = re.compile(rf"\b{re.escape(name)}\b")
    return sum(len(pattern.findall(text)) for text in sources.values())


def is_exempt_function(name):
    """Dice si la función la llama el motor o el ejecutor de pruebas."""
    return name in ENGINE_CALLBACKS or name in TEST_HOOKS or name.startswith(TEST_PREFIX)


def find_unused(sources):
    """Devuelve la lista de hallazgos como textos legibles."""
    findings = []
    scripts = {path: text for path, text in sources.items() if path.suffix == ".gd"}
    for path, text in scripts.items():
        for name in FUNC_PATTERN.findall(text):
            if not is_exempt_function(name) and count_references(name, sources) <= 1:
                findings.append(f"{path}: función sin uso '{name}'")
        for name in SIGNAL_PATTERN.findall(text):
            connected = re.compile(rf"\b{re.escape(name)}\.connect\(")
            if not any(connected.search(other) for other in sources.values()):
                findings.append(f"{path}: señal sin oyentes '{name}'")
        for name in MEMBER_PATTERN.findall(text):
            if count_references(name, sources) <= 1:
                findings.append(f"{path}: constante o variable sin uso '{name}'")
    return findings


def main():
    """Imprime los hallazgos y sale con error si hay alguno."""
    findings = find_unused(collect_sources(sys.argv[1:]))
    for finding in findings:
        print(finding)
    if findings:
        print(f"\n{len(findings)} elementos sin uso")
        sys.exit(1)
    print("Sin código sin uso")


if __name__ == "__main__":
    main()
