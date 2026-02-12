#!/usr/bin/env python3
"""Select the best fold/checkpoint from SIEVE CV outputs."""

from __future__ import annotations

import argparse
import csv
import math
import pathlib
import shutil
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

METRICS_FILE_CANDIDATES = ("fold_info.yaml", "results.yaml", "metrics.yaml", "cv_results.yaml")
CONFIG_FILE_CANDIDATES = ("config.yaml", "fold_config.yaml")
CHECKPOINT_FILE_CANDIDATES = ("best_model.pt", "checkpoint.pt", "model.pt")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fold-dir",
        dest="fold_dirs",
        action="append",
        required=True,
        help="Fold directory containing metrics/config/checkpoint files (repeatable)",
    )
    parser.add_argument("--out-best-checkpoint", default="best_checkpoint.pt")
    parser.add_argument("--out-best-config", default="best_fold_config.yaml")
    parser.add_argument("--out-best-fold-id", default="best_fold_id.txt")
    parser.add_argument("--out-summary", default="cv_folds_summary.tsv")
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


def pick_first_existing(directory: pathlib.Path, candidates: Iterable[str]) -> pathlib.Path | None:
    for name in candidates:
        pth = directory / name
        if pth.exists():
            return pth
    return None


def main() -> int:
    args = parse_args()

    rows: List[Dict[str, Any]] = []

    for fold_dir_arg in args.fold_dirs:
        fold_dir = pathlib.Path(fold_dir_arg).resolve()
        if not fold_dir.exists() or not fold_dir.is_dir():
            raise SystemExit(f"Fold directory does not exist or is not a directory: {fold_dir}")

        fold_id = fold_dir.name
        metrics_file = pick_first_existing(fold_dir, METRICS_FILE_CANDIDATES)
        config_file = pick_first_existing(fold_dir, CONFIG_FILE_CANDIDATES)
        checkpoint_file = pick_first_existing(fold_dir, CHECKPOINT_FILE_CANDIDATES)

        if metrics_file is None:
            raise SystemExit(f"Missing fold metrics YAML in {fold_dir}; tried {METRICS_FILE_CANDIDATES}")
        if config_file is None:
            raise SystemExit(f"Missing fold config YAML in {fold_dir}; tried {CONFIG_FILE_CANDIDATES}")
        if checkpoint_file is None:
            raise SystemExit(f"Missing fold checkpoint file in {fold_dir}; tried {CHECKPOINT_FILE_CANDIDATES}")

        metrics_data = load_yaml(metrics_file)
        flat_metrics = flatten_dict(metrics_data)

        rows.append(
            {
                "fold_id": fold_id,
                "auc": pick_metric(flat_metrics, AUC_KEYS),
                "accuracy": pick_metric(flat_metrics, ACC_KEYS),
                "loss": pick_metric(flat_metrics, LOSS_KEYS),
                "metrics_yaml": str(metrics_file),
                "config_yaml": str(config_file),
                "checkpoint": str(checkpoint_file),
                "config_path": config_file,
                "checkpoint_path": checkpoint_file,
            }
        )

    if not rows:
        raise SystemExit("No fold directories were provided")

    rows_sorted = sorted(
        rows,
        key=lambda row: (
            metric_rank_value(row["auc"], maximize=True),
            metric_rank_value(row["accuracy"], maximize=True),
            metric_rank_value(row["loss"], maximize=False),
            row["fold_id"],
        ),
    )

    best = rows_sorted[0]

    shutil.copyfile(best["checkpoint_path"], args.out_best_checkpoint)
    shutil.copyfile(best["config_path"], args.out_best_config)
    pathlib.Path(args.out_best_fold_id).write_text(f"{best['fold_id']}\n", encoding="utf-8")

    with pathlib.Path(args.out_summary).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["fold_id", "auc", "accuracy", "loss", "metrics_yaml", "config_yaml", "checkpoint"])
        for row in rows_sorted:
            writer.writerow(
                [
                    row["fold_id"],
                    "" if math.isnan(row["auc"]) else row["auc"],
                    "" if math.isnan(row["accuracy"]) else row["accuracy"],
                    "" if math.isnan(row["loss"]) else row["loss"],
                    row["metrics_yaml"],
                    row["config_yaml"],
                    row["checkpoint"],
                ]
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
