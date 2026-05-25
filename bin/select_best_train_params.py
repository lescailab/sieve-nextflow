#!/usr/bin/env python3
"""Select best hyperparameters from multiple SIEVE training runs."""

from __future__ import annotations

import argparse
import csv
import math
import pathlib
import sys
from typing import Any, Dict, Iterable, List

try:  # Optional dependency
    import yaml as pyyaml
except ImportError:  # pragma: no cover - runtime environment guard
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

HYPERPARAM_KEYS = (
    "lr",
    "learning_rate",
    "latent_dim",
    "hidden_dim",
    "num_attention_layers",
    "lambda_attr",
    "lambda",
    "batch_size",
    "chunk_size",
    "aggregation_method",
    "gradient_accumulation_steps",
    "gradient_clip",
    "early_stopping",
    "annotation_level",
    "device",
    "weight_decay",
    "dropout",
    "epochs",
    "val_split",
    "seed",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-dir",
        dest="run_dirs",
        action="append",
        required=True,
        help="Run directory containing results.yaml and config.yaml (repeatable)",
    )
    parser.add_argument("--out-best-params", default="best_params.yaml")
    parser.add_argument("--out-best-run-id", default="best_run_id.txt")
    parser.add_argument("--out-summary", default="train_grid_summary.tsv")
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
            # Minimal parser ignores list-only structures for robustness.
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


def _yaml_load_mapping(path: pathlib.Path) -> Dict[str, Any]:
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
            raise ValueError(f"Expected a YAML mapping at: {path}")
        return data

    data = _naive_yaml_load(text)
    if not isinstance(data, dict):
        raise ValueError(f"Expected a YAML mapping at: {path}")
    return data


def _yaml_dump(value: Any, path: pathlib.Path) -> None:
    if pyyaml is not None:
        with path.open("w", encoding="utf-8") as handle:
            pyyaml.safe_dump(value, handle, sort_keys=True)
        return

    def render(node: Any, indent: int = 0) -> List[str]:
        prefix = " " * indent
        if isinstance(node, dict):
            lines: List[str] = []
            for key in sorted(node.keys()):
                item = node[key]
                if isinstance(item, (dict, list)):
                    lines.append(f"{prefix}{key}:")
                    lines.extend(render(item, indent + 2))
                else:
                    scalar = "null" if item is None else str(item)
                    lines.append(f"{prefix}{key}: {scalar}")
            return lines
        if isinstance(node, list):
            lines = []
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


def extract_hyperparams(config: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(config.get("hyperparameters"), dict):
        return dict(config["hyperparameters"])

    flat = flatten_dict(config)
    params: Dict[str, Any] = {}
    for key in HYPERPARAM_KEYS:
        if key.lower() in flat:
            params[key] = flat[key.lower()]

    if params:
        return params

    fallback: Dict[str, Any] = {}
    for key, value in config.items():
        lower = str(key).lower()
        if any(token in lower for token in ("path", "file", "dir", "checkpoint", "run_id")):
            continue
        if isinstance(value, (str, int, float, bool)) or value is None:
            fallback[str(key)] = value
    return fallback


def main() -> int:
    args = parse_args()

    rows: List[Dict[str, Any]] = []
    seen_run_ids: set[str] = set()

    for run_dir_arg in args.run_dirs:
        run_dir = pathlib.Path(run_dir_arg).resolve()
        if not run_dir.exists() or not run_dir.is_dir():
            raise SystemExit(f"Run directory does not exist or is not a directory: {run_dir}")

        run_id = run_dir.name
        if run_id in seen_run_ids:
            raise SystemExit(f"Duplicate run identifier detected: {run_id}")
        seen_run_ids.add(run_id)

        results_yaml = run_dir / "results.yaml"
        config_yaml = run_dir / "config.yaml"

        results_data = _yaml_load_mapping(results_yaml)
        config_data = _yaml_load_mapping(config_yaml)

        flat_results = flatten_dict(results_data)
        auc = pick_metric(flat_results, AUC_KEYS)
        acc = pick_metric(flat_results, ACC_KEYS)
        loss = pick_metric(flat_results, LOSS_KEYS)

        rows.append(
            {
                "run_id": run_id,
                "results_yaml": str(results_yaml),
                "config_yaml": str(config_yaml),
                "auc": auc,
                "accuracy": acc,
                "loss": loss,
                "config": config_data,
            }
        )

    if not rows:
        raise SystemExit("No training runs were provided")

    rows_sorted = sorted(
        rows,
        key=lambda row: (
            metric_rank_value(row["auc"], maximize=True),
            metric_rank_value(row["accuracy"], maximize=True),
            metric_rank_value(row["loss"], maximize=False),
            row["run_id"],
        ),
    )

    best = rows_sorted[0]
    best_params = extract_hyperparams(best["config"])

    if not best_params:
        raise SystemExit(f"Failed to extract hyperparameters from best config: {best['config_yaml']}")

    out_summary = pathlib.Path(args.out_summary)
    with out_summary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["run_id", "auc", "accuracy", "loss", "results_yaml", "config_yaml"])
        for row in rows_sorted:
            writer.writerow(
                [
                    row["run_id"],
                    "" if math.isnan(row["auc"]) else row["auc"],
                    "" if math.isnan(row["accuracy"]) else row["accuracy"],
                    "" if math.isnan(row["loss"]) else row["loss"],
                    row["results_yaml"],
                    row["config_yaml"],
                ]
            )

    _yaml_dump(best_params, pathlib.Path(args.out_best_params))
    pathlib.Path(args.out_best_run_id).write_text(f"{best['run_id']}\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
