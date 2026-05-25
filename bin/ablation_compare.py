#!/usr/bin/env python3
"""Summarize ablation performance across annotation levels."""

from __future__ import annotations

import argparse
import csv
import math
import pathlib
import re
import sys
from typing import Any, Dict, Iterable, List

try:  # Optional dependency
    import yaml as pyyaml
except ImportError:  # pragma: no cover - runtime guard
    pyyaml = None


AUC_KEYS = (
    "auc",
    "roc_auc",
    "metrics.auc",
    "metrics.roc_auc",
    "validation.auc",
    "validation.roc_auc",
    "val.auc",
    "val.roc_auc",
    "val_auc",
)

ACC_KEYS = (
    "accuracy",
    "acc",
    "metrics.accuracy",
    "metrics.acc",
    "validation.accuracy",
    "validation.acc",
    "val.accuracy",
    "val.acc",
    "val_accuracy",
)

LOSS_KEYS = (
    "loss",
    "metrics.loss",
    "validation.loss",
    "val.loss",
    "val_loss",
)

LEVEL_ORDER = {"L0": 0, "L1": 1, "L2": 2, "L3": 3}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-dir",
        dest="run_dirs",
        action="append",
        required=True,
        help="Ablation run directory containing results.yaml and config.yaml (repeatable)",
    )
    parser.add_argument("--out-summary-tsv", default="ablation_summary.tsv")
    parser.add_argument("--out-summary-yaml", default="ablation_summary.yaml")
    return parser.parse_args()


def _parse_scalar(value: str) -> Any:
    value = value.strip()
    if not value:
        return ""
    if value in {"null", "Null", "NULL", "~"}:
        return None
    if value in {"true", "True", "TRUE"}:
        return True
    if value in {"false", "False", "FALSE"}:
        return False

    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        return value[1:-1]

    try:
        if value.startswith("0") and value not in {"0", "0.0"} and not value.startswith("0."):
            raise ValueError
        return int(value)
    except ValueError:
        pass

    try:
        return float(value)
    except ValueError:
        return value


def _naive_yaml_load(text: str) -> Dict[str, Any]:
    root: Dict[str, Any] = {}
    stack: List[tuple[int, Dict[str, Any]]] = [(-1, root)]

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if stripped.startswith("- "):
            continue

        if ":" not in stripped:
            continue

        key, raw_value = stripped.split(":", 1)
        key = key.strip()
        value = raw_value.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1] if stack else root

        if value == "":
            child: Dict[str, Any] = {}
            parent[key] = child
            stack.append((indent, child))
        else:
            parent[key] = _parse_scalar(value)

    return root


def load_yaml(path: pathlib.Path) -> Dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")

    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}

    if pyyaml is not None:
        data = pyyaml.safe_load(text)
        if data is None:
            return {}
        if not isinstance(data, dict):
            raise ValueError(f"Expected YAML mapping at: {path}")
        return data

    data = _naive_yaml_load(text)
    if not isinstance(data, dict):
        raise ValueError(f"Expected YAML mapping at: {path}")
    return data


def dump_yaml(value: Any, path: pathlib.Path) -> None:
    if pyyaml is not None:
        with path.open("w", encoding="utf-8") as handle:
            pyyaml.safe_dump(value, handle, sort_keys=False)
        return

    def render(node: Any, indent: int = 0) -> List[str]:
        prefix = " " * indent
        if isinstance(node, dict):
            lines: List[str] = []
            for key, item in node.items():
                if isinstance(item, (dict, list)):
                    lines.append(f"{prefix}{key}:")
                    lines.extend(render(item, indent + 2))
                else:
                    scalar = "null" if item is None else str(item)
                    lines.append(f"{prefix}{key}: {scalar}")
            return lines
        if isinstance(node, list):
            lines: List[str] = []
            for item in node:
                if isinstance(item, dict):
                    lines.append(f"{prefix}-")
                    lines.extend(render(item, indent + 2))
                elif isinstance(item, list):
                    lines.append(f"{prefix}-")
                    lines.extend(render(item, indent + 2))
                else:
                    scalar = "null" if item is None else str(item)
                    lines.append(f"{prefix}- {scalar}")
            return lines
        scalar = "null" if node is None else str(node)
        return [f"{prefix}{scalar}"]

    path.write_text("\n".join(render(value)) + "\n", encoding="utf-8")


def flatten_dict(obj: Dict[str, Any], prefix: str = "") -> Dict[str, Any]:
    flat: Dict[str, Any] = {}
    for key, value in obj.items():
        dotted = f"{prefix}.{key}" if prefix else str(key)
        flat[dotted.lower()] = value
        if isinstance(value, dict):
            flat.update(flatten_dict(value, dotted))
    return flat


def as_float(value: Any) -> float:
    if value is None:
        return math.nan
    try:
        return float(value)
    except (TypeError, ValueError):
        return math.nan


def pick_metric(flat: Dict[str, Any], keys: Iterable[str]) -> float:
    for key in keys:
        if key.lower() in flat:
            return as_float(flat[key.lower()])
    return math.nan


def metric_rank_value(value: float, maximize: bool) -> float:
    if math.isnan(value):
        return math.inf
    return -value if maximize else value


def resolve_level(run_id: str, config_data: Dict[str, Any]) -> str:
    level_candidates = [
        config_data.get("annotation_level"),
        config_data.get("level"),
        (config_data.get("train") or {}).get("annotation_level") if isinstance(config_data.get("train"), dict) else None,
    ]
    for candidate in level_candidates:
        if isinstance(candidate, str) and candidate in LEVEL_ORDER:
            return candidate

    match = re.search(r"(L[0-3])", run_id)
    if match:
        return match.group(1)

    return "UNKNOWN"


def main() -> int:
    args = parse_args()

    rows: List[Dict[str, Any]] = []

    for run_dir_arg in args.run_dirs:
        run_dir = pathlib.Path(run_dir_arg).resolve()
        if not run_dir.exists() or not run_dir.is_dir():
            raise SystemExit(f"Run directory does not exist or is not a directory: {run_dir}")

        run_id = run_dir.name
        results_yaml = run_dir / "results.yaml"
        config_yaml = run_dir / "config.yaml"

        results_data = load_yaml(results_yaml)
        config_data = load_yaml(config_yaml)

        flat_results = flatten_dict(results_data)

        rows.append(
            {
                "run_id": run_id,
                "level": resolve_level(run_id, config_data),
                "auc": pick_metric(flat_results, AUC_KEYS),
                "accuracy": pick_metric(flat_results, ACC_KEYS),
                "loss": pick_metric(flat_results, LOSS_KEYS),
                "results_yaml": str(results_yaml),
            }
        )

    if not rows:
        raise SystemExit("No ablation runs were provided")

    rows_sorted = sorted(
        rows,
        key=lambda row: (
            LEVEL_ORDER.get(row["level"], math.inf),
            row["run_id"],
        ),
    )

    ranked_rows = sorted(
        rows,
        key=lambda row: (
            metric_rank_value(row["auc"], maximize=True),
            metric_rank_value(row["accuracy"], maximize=True),
            metric_rank_value(row["loss"], maximize=False),
            LEVEL_ORDER.get(row["level"], math.inf),
            row["run_id"],
        ),
    )
    best = ranked_rows[0]

    with pathlib.Path(args.out_summary_tsv).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["level", "run_id", "auc", "accuracy", "loss", "results_yaml"])
        for row in rows_sorted:
            writer.writerow(
                [
                    row["level"],
                    row["run_id"],
                    "" if math.isnan(row["auc"]) else row["auc"],
                    "" if math.isnan(row["accuracy"]) else row["accuracy"],
                    "" if math.isnan(row["loss"]) else row["loss"],
                    row["results_yaml"],
                ]
            )

    summary_yaml = {
        "best_level": best["level"],
        "best_run_id": best["run_id"],
        "ranking_metric_priority": ["auc", "accuracy", "loss"],
        "levels": [
            {
                "level": row["level"],
                "run_id": row["run_id"],
                "auc": None if math.isnan(row["auc"]) else row["auc"],
                "accuracy": None if math.isnan(row["accuracy"]) else row["accuracy"],
                "loss": None if math.isnan(row["loss"]) else row["loss"],
            }
            for row in rows_sorted
        ],
    }

    dump_yaml(summary_yaml, pathlib.Path(args.out_summary_yaml))

    return 0


if __name__ == "__main__":
    sys.exit(main())
