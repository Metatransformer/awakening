#!/usr/bin/env python3
"""Validate the narrow machine-readable Awakening lore subset."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
LORE = ROOT / "lore"

REQUIRED_FILES = {
    "lore/README.md",
    "lore/index.yml",
    "lore/world.yml",
    "lore/gods.yml",
    "lore/story_items.yml",
    "lore/people/kael.yml",
    "lore/people/aldric_vane.yml",
    "lore/people/kessa.yml",
    "lore/people/brannoc.yml",
    "lore/people/ysolt.yml",
    "lore/people/marisel.yml",
}

PERSON_FILES = {
    "lore/people/kael.yml": "person.kael",
    "lore/people/aldric_vane.yml": "person.aldric_vane",
    "lore/people/kessa.yml": "person.kessa",
    "lore/people/brannoc.yml": "person.brannoc",
    "lore/people/ysolt.yml": "person.ysolt",
    "lore/people/marisel.yml": "person.marisel",
}

PERSON_FIELDS = {
    "schema_version",
    "id",
    "canonical_name",
    "display_name",
    "name_status",
    "role",
    "gender",
    "pronouns",
    "dialogue_id",
    "voice_status",
    "fixed_facts",
    "sources",
}

VALID_PRONOUNS = {
    "male": ("he", "him", "his", "himself"),
    "female": ("she", "her", "her", "herself"),
}

VALID_VOICE_STATUSES = {
    "silent",
    "partially_voiced",
    "partially_voiced_recast_pending",
}

VALID_NAME_STATUSES = {"tentative", "placeholder"}

EXPECTED_GENDERS = {
    "hero": "male",
    "elder": "male",
    "quartermaster": "female",
    "smith": "male",
    "alchemist": "male",
    "jewelcrafter": "female",
}

STORY_ITEM_IDS = {
    "story_item.makers_mark",
    "story_item.prior_cadet_lantern_piece",
    "story_place.sunken_cut",
}


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def missing_fields(data: Any, required: set[str]) -> list[str]:
    if not isinstance(data, dict):
        return sorted(required)
    return sorted(field for field in required if field not in data)


def load_yaml(path: Path, errors: list[str]) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"{relative(path)}: malformed or unreadable YAML: {exc}")
        return None
    if not isinstance(data, dict):
        errors.append(f"{relative(path)}: top level must be a mapping")
        return None
    return data


def dialogue_people(errors: list[str]) -> dict[str, str]:
    path = ROOT / "scripts/world/dialogue_db.gd"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"scripts/world/dialogue_db.gd: unreadable: {exc}")
        return {}

    match = re.search(
        r"static var PEOPLE := \{(?P<body>.*?)\n\}\n\n## take",
        text,
        flags=re.DOTALL,
    )
    if not match:
        errors.append("scripts/world/dialogue_db.gd: could not locate DialogueDb.PEOPLE")
        return {}

    people = dict(
        re.findall(
            r'&"([^\"]+)"\s*:\s*\{\s*"name"\s*:\s*"([^\"]+)"',
            match.group("body"),
            flags=re.DOTALL,
        )
    )
    if not people:
        errors.append("scripts/world/dialogue_db.gd: DialogueDb.PEOPLE is empty or unparseable")
    return people


def collect_ids(value: Any, location: str, found: dict[str, str], errors: list[str]) -> None:
    if isinstance(value, dict):
        entity_id = value.get("id")
        if entity_id is not None:
            if not isinstance(entity_id, str) or not entity_id.strip():
                errors.append(f"{location}: id must be a non-empty string")
            elif entity_id in found:
                errors.append(f"{location}: duplicate id {entity_id!r}; first seen in {found[entity_id]}")
            else:
                found[entity_id] = location
        for key, child in value.items():
            collect_ids(child, f"{location}.{key}", found, errors)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            collect_ids(child, f"{location}[{index}]", found, errors)


def validate_sources(
    sources: Any,
    location: str,
    declared_sources: set[str],
    errors: list[str],
) -> None:
    if not isinstance(sources, list) or not sources:
        errors.append(f"{location}: sources must be a non-empty list")
        return
    for source in sources:
        if not isinstance(source, str) or not source:
            errors.append(f"{location}: source references must be non-empty paths")
            continue
        if source not in declared_sources:
            errors.append(f"{location}: source {source!r} is not declared in lore/index.yml")
        if not (ROOT / source).is_file():
            errors.append(f"{location}: source path does not exist: {source}")


def validate_person(
    path: str,
    data: Any,
    dialogue: dict[str, str],
    declared_sources: set[str],
    errors: list[str],
) -> None:
    missing = missing_fields(data, PERSON_FIELDS)
    if missing:
        errors.append(f"{path}: missing required fields: {', '.join(missing)}")
        return

    if data["schema_version"] != 1:
        errors.append(f"{path}: schema_version must be 1")
    if data["id"] != PERSON_FILES[path]:
        errors.append(f"{path}: expected id {PERSON_FILES[path]!r}, got {data['id']!r}")

    for field in ("canonical_name", "display_name", "name_status", "role", "gender", "dialogue_id"):
        if not isinstance(data[field], str) or not data[field].strip():
            errors.append(f"{path}: {field} must be a non-empty string")

    if not isinstance(data["name_status"], str) or data["name_status"] not in VALID_NAME_STATUSES:
        errors.append(f"{path}: invalid name_status {data['name_status']!r}")

    pronouns = data["pronouns"]
    pronoun_fields = ("subject", "object", "possessive", "reflexive")
    if not isinstance(pronouns, dict) or set(pronouns) != set(pronoun_fields):
        errors.append(f"{path}: pronouns must contain exactly {', '.join(pronoun_fields)}")
    else:
        record = tuple(pronouns[field] for field in pronoun_fields)
        expected_pronouns = (
            VALID_PRONOUNS.get(data["gender"])
            if isinstance(data["gender"], str)
            else None
        )
        if not all(isinstance(value, str) for value in record) or record != expected_pronouns:
            errors.append(f"{path}: invalid pronoun record {record!r}")

    dialogue_id = data["dialogue_id"]
    if not isinstance(dialogue_id, str):
        errors.append(f"{path}: dialogue_id must be a string")
    elif dialogue_id not in dialogue:
        errors.append(f"{path}: unknown dialogue_id {dialogue_id!r} in DialogueDb.PEOPLE")
    elif data["display_name"] != dialogue[dialogue_id]:
        errors.append(
            f"{path}: display_name {data['display_name']!r} disagrees with "
            f"DialogueDb.PEOPLE name {dialogue[dialogue_id]!r}"
        )
    if isinstance(dialogue_id, str) and data["gender"] != EXPECTED_GENDERS.get(dialogue_id):
        errors.append(f"{path}: gender {data['gender']!r} disagrees with current canon")

    voice_status = data["voice_status"]
    if not isinstance(voice_status, str) or voice_status not in VALID_VOICE_STATUSES:
        errors.append(f"{path}: invalid voice_status {voice_status!r}")
    if dialogue_id == "hero" and voice_status != "silent":
        errors.append(f"{path}: the hero must remain silent")
    if dialogue_id != "hero" and voice_status == "silent":
        errors.append(f"{path}: non-hero garrison people currently speak")

    if not isinstance(data["fixed_facts"], list) or not data["fixed_facts"]:
        errors.append(f"{path}: fixed_facts must be a non-empty list")
    validate_sources(data["sources"], path, declared_sources, errors)


def validate_records_with_sources(
    records: Any,
    location: str,
    declared_sources: set[str],
    errors: list[str],
) -> None:
    if not isinstance(records, list) or not records:
        errors.append(f"{location}: must be a non-empty list")
        return
    for index, record in enumerate(records):
        record_location = f"{location}[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{record_location}: must be a mapping")
            continue
        if "id" not in record:
            errors.append(f"{record_location}: missing required field id")
        if "sources" not in record:
            errors.append(f"{record_location}: missing required field sources")
        else:
            validate_sources(record["sources"], record_location, declared_sources, errors)


def main() -> int:
    errors: list[str] = []

    for required in sorted(REQUIRED_FILES):
        if not (ROOT / required).is_file():
            errors.append(f"missing required file: {required}")

    yaml_paths = sorted(LORE.rglob("*.yml")) if LORE.is_dir() else []
    documents = {relative(path): load_yaml(path, errors) for path in yaml_paths}

    index = documents.get("lore/index.yml")
    index_missing = missing_fields(index, {"schema_version", "sources", "never_violate", "files"})
    if index_missing:
        errors.append(f"lore/index.yml: missing required fields: {', '.join(index_missing)}")
        declared_sources: set[str] = set()
    else:
        if index["schema_version"] != 1:
            errors.append("lore/index.yml: schema_version must be 1")
        source_rows = index["sources"]
        if not isinstance(source_rows, list) or not source_rows:
            errors.append("lore/index.yml: sources must be a non-empty list")
            declared_sources = set()
        else:
            declared_sources = set()
            for row in source_rows:
                if not isinstance(row, dict) or not isinstance(row.get("path"), str):
                    errors.append("lore/index.yml: every source needs a path")
                    continue
                source_path = row["path"]
                declared_sources.add(source_path)
                if not (ROOT / source_path).is_file():
                    errors.append(f"lore/index.yml: source path does not exist: {source_path}")

        manifest = index.get("files", [])
        if not isinstance(manifest, list) or any(not isinstance(item, str) for item in manifest):
            errors.append("lore/index.yml: files must be a list of paths")
        else:
            manifest_set = set(manifest)
            actual_files = {
                relative(path)
                for path in LORE.rglob("*")
                if path.is_file() and path.suffix in {".md", ".yml"}
            }
            if manifest_set != actual_files:
                missing_links = sorted(actual_files - manifest_set)
                stale_links = sorted(manifest_set - actual_files)
                if missing_links:
                    errors.append(f"lore/index.yml: unlinked files: {', '.join(missing_links)}")
                if stale_links:
                    errors.append(f"lore/index.yml: missing linked files: {', '.join(stale_links)}")
        if not isinstance(index.get("never_violate"), list) or not index["never_violate"]:
            errors.append("lore/index.yml: never_violate must be a non-empty list")

    dialogue = dialogue_people(errors)
    for path in sorted(PERSON_FILES):
        validate_person(path, documents.get(path), dialogue, declared_sources, errors)

    world = documents.get("lore/world.yml")
    world_missing = missing_fields(
        world,
        {"schema_version", "id", "scope", "fixed_reveal", "open_parent_canon_collisions", "sources"},
    )
    if world_missing:
        errors.append(f"lore/world.yml: missing required fields: {', '.join(world_missing)}")
    else:
        validate_sources(world["sources"], "lore/world.yml", declared_sources, errors)
        validate_records_with_sources(
            world["fixed_reveal"], "lore/world.yml.fixed_reveal", declared_sources, errors
        )
        validate_records_with_sources(
            world["open_parent_canon_collisions"],
            "lore/world.yml.open_parent_canon_collisions",
            declared_sources,
            errors,
        )
        for collision in world["open_parent_canon_collisions"]:
            if isinstance(collision, dict) and not str(collision.get("status", "")).startswith("unresolved"):
                errors.append(f"lore/world.yml: collision {collision.get('id')!r} is not unresolved")

    gods = documents.get("lore/gods.yml")
    gods_missing = missing_fields(
        gods,
        {"schema_version", "id", "scope", "prologue_status", "named_or_revealed", "fixed_fact", "use_rule", "sources"},
    )
    if gods_missing:
        errors.append(f"lore/gods.yml: missing required fields: {', '.join(gods_missing)}")
    else:
        validate_sources(gods["sources"], "lore/gods.yml", declared_sources, errors)
        if gods["prologue_status"] != "none_named_or_revealed":
            errors.append("lore/gods.yml: prologue_status must remain none_named_or_revealed")
        if gods["named_or_revealed"] != []:
            errors.append("lore/gods.yml: Awakening currently names or reveals no gods")

    story = documents.get("lore/story_items.yml")
    story_missing = missing_fields(story, {"schema_version", "id", "scope", "items", "sources"})
    if story_missing:
        errors.append(f"lore/story_items.yml: missing required fields: {', '.join(story_missing)}")
    else:
        validate_sources(story["sources"], "lore/story_items.yml", declared_sources, errors)
        validate_records_with_sources(story["items"], "lore/story_items.yml.items", declared_sources, errors)
        item_ids = {
            item.get("id")
            for item in story["items"]
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        }
        missing_items = sorted(STORY_ITEM_IDS - item_ids)
        if missing_items:
            errors.append(f"lore/story_items.yml: missing story items: {', '.join(missing_items)}")
        collision_ids = {
            collision.get("id")
            for collision in (world or {}).get("open_parent_canon_collisions", [])
            if isinstance(collision, dict) and isinstance(collision.get("id"), str)
        }
        for item in story["items"]:
            if not isinstance(item, dict):
                continue
            item_missing = missing_fields(
                item,
                {"id", "name", "kind", "status", "story_function", "fixed_facts", "collision_refs", "sources"},
            )
            if item_missing:
                errors.append(
                    f"lore/story_items.yml item {item.get('id')!r}: missing fields: "
                    f"{', '.join(item_missing)}"
                )
            refs = item.get("collision_refs", [])
            if not isinstance(refs, list):
                errors.append(f"lore/story_items.yml item {item.get('id')!r}: collision_refs must be a list")
            else:
                for ref in refs:
                    if not isinstance(ref, str) or ref not in collision_ids:
                        errors.append(
                            f"lore/story_items.yml item {item.get('id')!r}: unknown collision ref {ref!r}"
                        )

    found_ids: dict[str, str] = {}
    for path in sorted(documents):
        if documents[path] is not None:
            collect_ids(documents[path], path, found_ids, errors)

    if errors:
        for error in sorted(set(errors)):
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Lore validation passed: {len(documents)} YAML files, {len(PERSON_FILES)} people.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
