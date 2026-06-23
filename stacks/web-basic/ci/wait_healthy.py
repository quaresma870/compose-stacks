#!/usr/bin/env python3
"""
Used by .github/workflows/validate.yml's smoke-test job to poll
`docker compose ps --format json` until every service reports healthy
(or a timeout is hit).

Handles both known output shapes for --format json, since this changed
between Docker Compose versions and which one a given GitHub Actions
runner has pre-installed isn't something this workflow controls:
  - pre-2.21.0: a single JSON array: [{...}, {...}]
  - 2.21.0+: newline-delimited individual objects, no array wrapper: {...}\n{...}
"""

import json
import sys


def parse_compose_ps_json(raw: str) -> list[dict]:
    raw = raw.strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
        # A single object (only one container) is valid JSON on its own —
        # normalise to a list either way.
        return data if isinstance(data, list) else [data]
    except json.JSONDecodeError:
        pass

    containers = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        containers.append(json.loads(line))
    return containers


def main() -> int:
    raw = sys.stdin.read()
    containers = parse_compose_ps_json(raw)

    unhealthy = []
    for c in containers:
        health = c.get("Health", "")
        # Services with no healthcheck at all report an empty Health string —
        # that's not a failure, just nothing to wait on for that service.
        if health and health != "healthy":
            unhealthy.append(f"{c.get('Service', c.get('Name', '?'))}:{health}")

    print(",".join(unhealthy))
    return 0


if __name__ == "__main__":
    sys.exit(main())
