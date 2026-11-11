#!/usr/bin/env python3
"""Check course registration, lab boundaries and local runtime references."""
from collections import Counter
from pathlib import Path
import re
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
errors = []
QUESTION_SHAPE = ("Solve this question on: `terminal`", "## Tasks", "## Constraints", "## How the answer is checked")


def require(condition, message):
    if not condition:
        errors.append(message)


def read_yaml(path):
    try:
        return yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


outline = read_yaml(ROOT / "astrona.yaml")
registered = []
for section in outline.get("modules", []):
    content = section.get("content", [])
    for index, item in enumerate(content):
        path = item.get("path", "")
        require(bool(path) and (ROOT / path).exists(), f"Missing course path: {path}")
        if item.get("type") != "lab":
            continue
        registered.append(path)
        require(index > 0 and content[index - 1].get("path") == path + "/question.md",
                f"{path}: lab must follow its question reading")
        if "/module-" not in path:
            continue
        # Module labs are exam questions in ATS020's shape. Capstones combine
        # a section's skills on purpose and keep their longer brief.
        question = ROOT / path / "question.md"
        if question.is_file():
            text = question.read_text()
            for heading in QUESTION_SHAPE:
                require(heading in text, f"{path}: question.md lacks {heading!r}")
            tasks_block = re.search(r"^## Tasks\n(.*?)(?=^## |\Z)", text, re.M | re.S)
            tasks = re.findall(r"^\d+\.\s+", tasks_block.group(1), re.M) if tasks_block else []
            require(2 <= len(tasks) <= 4, f"{path}: expected 2–4 tasks, found {len(tasks)}")
            require(re.search(r"^Allow (about )?\d+([–-]\d+)? minutes ", text, re.M),
                    f"{path}: question.md lacks the time line")

counts = Counter(registered)
for path, count in counts.items():
    require(count == 1, f"Duplicate lab registration: {path}")

runtime_names = {}
module_labs = 0
for config in sorted((ROOT / "sections").rglob("config.yaml")):
    environment = config.parent
    if environment.name != "playground" and environment.parent.name != "labs":
        continue
    relative = str(environment.relative_to(ROOT))
    data = read_yaml(config)
    name = data.get("metadata", {}).get("name")
    require(bool(name), f"{relative}: missing runtime name")
    require(name not in runtime_names,
            f"{relative}: runtime name {name} also used by {runtime_names.get(name)}")
    runtime_names[name] = relative
    if environment.parent.name == "labs":
        require(relative in counts, f"Unregistered lab: {relative}")
        validation = data.get("validation", {})
        if "/module-" in relative:
            module_labs += 1
            scripts = validation.get("scripts") or []
            require(bool(scripts), f"{relative}: no graders")
            for script in scripts:
                require(bool(script.get("description")) and bool(script.get("points")),
                        f"{relative}: grader {script.get('name')} needs a description and points")
            steps = data.get("testing", {}).get("init", [])
            require(bool(steps) and steps[0].get("source") == "testing/verify-start.sh",
                    f"{relative}: verify the starting state before the solution")
        else:
            # Capstones still use the single-grader form.
            require(bool(validation.get("scripts") or validation.get("script")), f"{relative}: no graders")
        require(bool(data.get("testing", {}).get("init")), f"{relative}: no reference lifecycle")
    for value in data.get("metadata", {}).get("docs", {}).values():
        require((environment / value).is_file(), f"{relative}: missing document {value}")

    def check_sources(value):
        if isinstance(value, dict):
            if value.get("type") == "file" and "source" in value:
                require((environment / value["source"]).is_file(),
                        f"{relative}: missing source {value['source']}")
            for child in value.values():
                check_sources(child)
        elif isinstance(value, list):
            for child in value:
                check_sources(child)

    check_sources(data)

for quiz in (ROOT / "sections").rglob("*quiz.yaml"):
    for question in read_yaml(quiz).get("questions", []):
        for reading in question.get("source_readings", []):
            require((ROOT / reading).is_file(), f"{quiz.relative_to(ROOT)}: missing reading {reading}")

if errors:
    print("\n".join(f"FAIL: {error}" for error in errors))
    sys.exit(1)
print(f"PASS: {len(registered)} registered labs, {module_labs} module labs, {len(runtime_names)} unique environments")
