#!/usr/bin/env python3
"""
Validador de Integridad para el Vault de Obsidian: PJ-NIRI-rf-omarchy-workstation
Verifica:
1. Existencia y formato del frontmatter YAML (title, tags, aliases, date).
2. Resolución de todos los wikilinks ([[Nota|Alias]] y [[Nota]]).
3. Balance y cierre correcto de bloques de código (```).
4. Integridad de enlaces a recursos en assets/.
"""

import os
import re
import sys

VAULT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def get_markdown_files():
    md_files = []
    for root, _, files in os.walk(VAULT_ROOT):
        if ".git" in root or ".obsidian" in root:
            continue
        for f in files:
            if f.endswith(".md"):
                md_files.append(os.path.join(root, f))
    return sorted(md_files)

def parse_frontmatter(content):
    if not content.startswith("---"):
        return None, content
    parts = content.split("---", 2)
    if len(parts) < 3:
        return None, content
    fm_lines = parts[1].strip().splitlines()
    data = {}
    current_key = None
    for line in fm_lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line and not line.startswith("-"):
            k, v = line.split(":", 1)
            current_key = k.strip()
            v = v.strip()
            data[current_key] = v if v else []
        elif line.startswith("- ") and current_key:
            if isinstance(data[current_key], list):
                data[current_key].append(line[2:].strip())
    return data, parts[2]

def check_vault():
    md_files = get_markdown_files()
    all_note_names = {os.path.splitext(os.path.basename(f))[0]: f for f in md_files}
    all_rel_paths = {os.path.relpath(f, VAULT_ROOT): f for f in md_files}
    
    errors = []
    warnings = []
    total_links = 0

    print(f"🔍 Escaneando {len(md_files)} notas Markdown en {VAULT_ROOT}...\n")

    for file_path in md_files:
        rel_path = os.path.relpath(file_path, VAULT_ROOT)
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        # 1. Frontmatter
        if rel_path in ["README.md", "AGENTS.md"]:
            fm = None
        else:
            fm, _ = parse_frontmatter(content)
            if fm is None or isinstance(fm, str):
                errors.append(f"[{rel_path}] Frontmatter inválido o ausente ({fm}).")
            else:
                for required in ["title", "tags", "aliases", "date"]:
                    if required not in fm:
                        warnings.append(f"[{rel_path}] Frontmatter no contiene el campo recomendado '{required}'.")

        # 2. Code blocks balance
        fence_count = len(re.findall(r"^```", content, re.MULTILINE))
        if fence_count % 2 != 0:
            errors.append(f"[{rel_path}] Desbalance de bloques de código: {fence_count} delimitadores ``` encontrados.")

        # 3. Strip code blocks before checking wikilinks
        no_blocks = re.sub(r"```[\s\S]*?```", "", content)
        no_inline = re.sub(r"`[^`\n]+`", "", no_blocks)

        # 4. Wikilinks check
        wikilinks = re.findall(r"\[\[(.*?)\]\]", no_inline)
        for link in wikilinks:
            total_links += 1
            # Unescape \| that Obsidian uses inside markdown tables
            clean_link = link.replace(r"\|", "|")
            target = clean_link.split("|")[0].strip()
            # If target has heading #
            target_file = target.split("#")[0].strip()
            if not target_file:
                continue  # link to heading inside same file
            
            # Check if target exists in all_note_names or is an asset
            # Only strip extension if it's explicitly .md
            if target_file.endswith(".md"):
                base_target = os.path.basename(target_file)[:-3]
            else:
                base_target = os.path.basename(target_file)

            if base_target not in all_note_names and target_file not in all_rel_paths:
                # Check if asset
                asset_path = os.path.join(VAULT_ROOT, target_file)
                if not os.path.exists(asset_path):
                    errors.append(f"[{rel_path}] Wikilink roto: [[{link}]] -> No se encuentra '{target_file}'")

    print(f"📊 Estadísticas:")
    print(f"  • Notas analizadas: {len(md_files)}")
    print(f"  • Wikilinks auditados: {total_links}")
    print(f"  • Advertencias: {len(warnings)}")
    print(f"  • Errores críticos: {len(errors)}")

    if warnings:
        print("\n⚠️  Advertencias:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("\n❌ Errores:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("\n✅ Validación exitosa: Estructura 100% íntegra y saludable.")
    return 0

if __name__ == "__main__":
    sys.exit(check_vault())
