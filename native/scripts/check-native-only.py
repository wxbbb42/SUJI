#!/usr/bin/env python3
"""Reject retired client entry points and dependencies in the Git checkout."""

import json
from pathlib import Path
import subprocess
import sys


LEGACY_ROOTS = {"app", "assets", "components", "lib", "ios", "android", "dist", "web-build", ".expo"}
LEGACY_FILES = {
    "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
    "app.json", "eas.json", "expo-env.d.ts",
}


def legacy_dependency(name):
    return name in {"expo", "react", "react-dom", "react-native", "metro"} or name.startswith(
        ("expo-", "@expo/", "@react-native/", "@react-native-community/", "@react-navigation/", "metro-")
    )


def check_repository(root):
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
    issues = []
    for filename in filter(None, tracked):
        path = Path(filename)
        if path.parts[0] in LEGACY_ROOTS or (
            len(path.parts) == 1 and (
                filename in LEGACY_FILES or filename.startswith(("app.config.", "babel.config.", "metro.config."))
            )
        ):
            issues.append(f"Retired client path: {filename}")
        if path.name not in {"package.json", "package-lock.json"}:
            continue
        data = json.loads((root / path).read_text())
        if path.name == "package.json":
            names = {
                name for section in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies")
                for name in data.get(section, {})
            }
        else:
            names = {name.rsplit("node_modules/", 1)[-1] for name in data.get("packages", {}) if name}
        for name in sorted(filter(legacy_dependency, names)):
            issues.append(f"Retired client dependency in {filename}: {name}")
    return issues


if __name__ == "__main__":
    problems = check_repository(Path(__file__).resolve().parents[2])
    if problems:
        print("SwiftUI-only check failed:\n" + "\n".join(problems), file=sys.stderr)
        sys.exit(1)
    print("SwiftUI-only check passed: no tracked legacy client or Expo / React Native dependencies.")
