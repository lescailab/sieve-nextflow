#!/usr/bin/env python3
"""Compare variant attribution rankings across annotation levels L0-L3."""

from __future__ import annotations

import argparse
import csv
import itertools
import pathlib
import re
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

try:  # Optional dependency
    import yaml as pyyaml
except ImportError:  # pragma: no cover - runtime guard
    pyyaml = None


LEVEL_ORDER = ["L0", "L1", "L2", "L3"]


# ---------------------------------------------------------------------------
# YAML utilities (mirrors ablation_compare.py patterns)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# CSV loading
# ---------------------------------------------------------------------------

VARIANT_ID_COLUMNS = [
    "variant_id",
    "position",
    "variant",
    "feature",
    "feature_id",
]

SCORE_COLUMNS = [
    "mean_attribution",
    "score",
    "attribution",
    "mean_score",
    "importance",
]

GENE_COLUMNS = ["gene", "gene_name", "gene_symbol"]
CHROM_COLUMNS = ["chrom", "chromosome", "chr"]
POS_COLUMNS = ["pos", "position", "start"]


def _find_column(headers: List[str], candidates: List[str]) -> Optional[str]:
    """Find the first matching column name (case-insensitive)."""
    lower_headers = {h.lower(): h for h in headers}
    for candidate in candidates:
        if candidate.lower() in lower_headers:
            return lower_headers[candidate.lower()]
    return None


def _build_variant_id(row: Dict[str, str], headers: List[str]) -> Optional[str]:
    """Build a variant ID from explicit column or from chrom+pos+ref+alt."""
    vid_col = _find_column(headers, VARIANT_ID_COLUMNS)
    if vid_col and row.get(vid_col, "").strip():
        return row[vid_col].strip()

    chrom_col = _find_column(headers, CHROM_COLUMNS)
    pos_col = _find_column(headers, POS_COLUMNS)
    ref_col = _find_column(headers, ["ref", "reference"])
    alt_col = _find_column(headers, ["alt", "alternative", "allele"])

    if chrom_col and pos_col:
        chrom = row.get(chrom_col, "").strip()
        pos = row.get(pos_col, "").strip()
        ref = row.get(ref_col, "").strip() if ref_col else ""
        alt = row.get(alt_col, "").strip() if alt_col else ""
        if chrom and pos:
            base = f"{chrom}:{pos}"
            if ref and alt:
                return f"{base}_{ref}/{alt}"
            return base
    return None


def _get_score(row: Dict[str, str], headers: List[str]) -> float:
    """Extract attribution score from a row."""
    score_col = _find_column(headers, SCORE_COLUMNS)
    if score_col:
        try:
            return float(row[score_col])
        except (ValueError, TypeError):
            return 0.0
    return 0.0


def _get_field(row: Dict[str, str], headers: List[str], candidates: List[str]) -> str:
    """Get a field value from a row, trying multiple column names."""
    col = _find_column(headers, candidates)
    if col:
        return row.get(col, "").strip()
    return ""


def load_rankings(csv_path: pathlib.Path) -> List[Dict[str, Any]]:
    """Load a variant ranking CSV and return ranked list of dicts."""
    with csv_path.open("r", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        headers = reader.fieldnames or []
        rows = []
        for row in reader:
            vid = _build_variant_id(row, headers)
            if vid is None:
                continue
            rows.append({
                "variant_id": vid,
                "score": _get_score(row, headers),
                "gene": _get_field(row, headers, GENE_COLUMNS),
                "chrom": _get_field(row, headers, CHROM_COLUMNS),
                "pos": _get_field(row, headers, POS_COLUMNS),
            })

    # Sort by score descending, assign ranks
    rows.sort(key=lambda r: -r["score"])
    for i, row in enumerate(rows):
        row["rank"] = i + 1

    return rows


def find_ranking_files(ranking_dir: pathlib.Path) -> Dict[str, pathlib.Path]:
    """Find variant ranking CSV files named with level prefix (e.g. L0_sieve_variant_rankings.csv)."""
    level_files: Dict[str, pathlib.Path] = {}
    for level in LEVEL_ORDER:
        pattern = f"{level}_sieve_variant_rankings.csv"
        candidates = list(ranking_dir.glob(pattern))
        if candidates:
            level_files[level] = candidates[0]
            continue
        # Try more flexible matching
        for f in ranking_dir.glob(f"{level}_*variant*rank*.csv"):
            level_files[level] = f
            break

    return level_files


# ---------------------------------------------------------------------------
# Analysis functions
# ---------------------------------------------------------------------------

def compute_jaccard(set_a: Set[str], set_b: Set[str]) -> Tuple[float, int, int]:
    """Compute Jaccard similarity and return (jaccard, overlap, union_size)."""
    if not set_a and not set_b:
        return 0.0, 0, 0
    intersection = set_a & set_b
    union = set_a | set_b
    jaccard = len(intersection) / len(union) if union else 0.0
    return jaccard, len(intersection), len(union)


def compute_jaccard_matrices(
    level_rankings: Dict[str, List[Dict[str, Any]]],
    top_k_values: List[int],
) -> Dict[int, List[Dict[str, Any]]]:
    """Compute pairwise Jaccard matrices for each top_k value."""
    matrices: Dict[int, List[Dict[str, Any]]] = {}
    levels = sorted(level_rankings.keys(), key=lambda l: LEVEL_ORDER.index(l) if l in LEVEL_ORDER else 999)

    for top_k in top_k_values:
        top_sets: Dict[str, Set[str]] = {}
        for level in levels:
            ranked = level_rankings[level]
            top_sets[level] = {r["variant_id"] for r in ranked[:top_k]}

        rows = []
        for la, lb in itertools.combinations(levels, 2):
            jaccard, overlap, union_size = compute_jaccard(top_sets[la], top_sets[lb])
            rows.append({
                "top_k": top_k,
                "level_a": la,
                "level_b": lb,
                "jaccard": round(jaccard, 4),
                "overlap": overlap,
                "size_a": len(top_sets[la]),
                "size_b": len(top_sets[lb]),
                "union": union_size,
            })
        matrices[top_k] = rows

    return matrices


def find_level_specific_variants(
    level_rankings: Dict[str, List[Dict[str, Any]]],
    high_rank_threshold: int,
    low_rank_threshold: int,
) -> List[Dict[str, Any]]:
    """
    Find variants in the top high_rank_threshold at one level
    but outside the top low_rank_threshold at all other levels.
    """
    levels = sorted(level_rankings.keys(), key=lambda l: LEVEL_ORDER.index(l) if l in LEVEL_ORDER else 999)

    # Build rank lookup per level: variant_id -> rank
    rank_lookup: Dict[str, Dict[str, int]] = {}
    info_lookup: Dict[str, Dict[str, Any]] = {}
    total_variants: Dict[str, int] = {}

    for level in levels:
        ranked = level_rankings[level]
        total_variants[level] = len(ranked)
        rank_lookup[level] = {}
        for r in ranked:
            rank_lookup[level][r["variant_id"]] = r["rank"]
            if r["variant_id"] not in info_lookup:
                info_lookup[r["variant_id"]] = {
                    "gene": r.get("gene", ""),
                    "chrom": r.get("chrom", ""),
                    "pos": r.get("pos", ""),
                }

    results = []
    for level in levels:
        other_levels = [l for l in levels if l != level]
        ranked = level_rankings[level]
        top_at_level = [r for r in ranked if r["rank"] <= high_rank_threshold]

        for variant_row in top_at_level:
            vid = variant_row["variant_id"]
            is_specific = True
            for other in other_levels:
                other_rank = rank_lookup[other].get(vid, total_variants[other] + 1)
                if other_rank <= low_rank_threshold:
                    is_specific = False
                    break

            if is_specific:
                info = info_lookup.get(vid, {})
                entry = {
                    "variant_id": vid,
                    "gene": info.get("gene", ""),
                    "chrom": info.get("chrom", ""),
                    "pos": info.get("pos", ""),
                    "specific_to_level": level,
                    "rank_at_specific_level": variant_row["rank"],
                    "mean_attribution_at_specific_level": variant_row["score"],
                }
                # Add rank at each level
                for l in LEVEL_ORDER:
                    if l in rank_lookup:
                        entry[f"rank_at_{l}"] = rank_lookup[l].get(vid, total_variants.get(l, 0) + 1)

                results.append(entry)

    return results


# ---------------------------------------------------------------------------
# CLI and main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ranking-dir",
        required=True,
        help="Directory containing variant ranking CSVs named as L{0,1,2,3}_sieve_variant_rankings.csv",
    )
    parser.add_argument(
        "--top-k",
        default="50,100,200,500",
        help="Comma-separated list of top-k values for Jaccard computation (default: 50,100,200,500)",
    )
    parser.add_argument(
        "--high-rank-threshold",
        type=int,
        default=100,
        help="Threshold for high-ranking variants (default: 100)",
    )
    parser.add_argument(
        "--low-rank-threshold",
        type=int,
        default=500,
        help="Threshold for low-ranking variants at other levels (default: 500)",
    )
    parser.add_argument("--out-comparison", default="ablation_ranking_comparison.yaml")
    parser.add_argument("--out-jaccard", default="ablation_jaccard_matrix.tsv")
    parser.add_argument("--out-level-specific", default="level_specific_variants.tsv")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ranking_dir = pathlib.Path(args.ranking_dir)
    top_k_values = [int(k.strip()) for k in args.top_k.split(",")]

    # Discover ranking files
    level_files = find_ranking_files(ranking_dir)
    if not level_files:
        print("ERROR: No ranking files found in {}".format(ranking_dir), file=sys.stderr)
        return 1

    levels_found = sorted(level_files.keys(), key=lambda l: LEVEL_ORDER.index(l) if l in LEVEL_ORDER else 999)
    print(f"Found ranking files for levels: {', '.join(levels_found)}", file=sys.stderr)

    # Load all rankings
    level_rankings: Dict[str, List[Dict[str, Any]]] = {}
    for level, fpath in level_files.items():
        level_rankings[level] = load_rankings(fpath)
        print(f"  {level}: {len(level_rankings[level])} variants from {fpath.name}", file=sys.stderr)

    if len(level_rankings) < 2:
        print("WARNING: Need at least 2 levels for comparison, found {}".format(len(level_rankings)), file=sys.stderr)

    # Compute Jaccard matrices
    jaccard_matrices = compute_jaccard_matrices(level_rankings, top_k_values)

    # Find level-specific variants
    level_specific = find_level_specific_variants(
        level_rankings,
        args.high_rank_threshold,
        args.low_rank_threshold,
    )

    # Write Jaccard TSV
    jaccard_path = pathlib.Path(args.out_jaccard)
    with jaccard_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(["top_k", "level_a", "level_b", "jaccard", "overlap", "size_a", "size_b", "union"])
        for top_k in top_k_values:
            for row in jaccard_matrices.get(top_k, []):
                writer.writerow([
                    row["top_k"],
                    row["level_a"],
                    row["level_b"],
                    row["jaccard"],
                    row["overlap"],
                    row["size_a"],
                    row["size_b"],
                    row["union"],
                ])

    # Write level-specific variants TSV
    level_specific_path = pathlib.Path(args.out_level_specific)
    rank_cols = [f"rank_at_{l}" for l in LEVEL_ORDER if l in level_rankings]
    fieldnames = [
        "variant_id", "gene", "chrom", "pos",
        "specific_to_level", "rank_at_specific_level",
    ] + rank_cols + ["mean_attribution_at_specific_level"]

    with level_specific_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        for row in level_specific:
            writer.writerow(row)

    # Write YAML summary
    yaml_summary: Dict[str, Any] = {
        "levels_analysed": levels_found,
        "top_k_values": top_k_values,
        "high_rank_threshold": args.high_rank_threshold,
        "low_rank_threshold": args.low_rank_threshold,
        "variants_per_level": {level: len(rankings) for level, rankings in level_rankings.items()},
        "jaccard_matrices": {},
        "level_specific_variant_counts": {},
    }

    for top_k in top_k_values:
        key = f"top_{top_k}"
        yaml_summary["jaccard_matrices"][key] = {}
        for row in jaccard_matrices.get(top_k, []):
            pair_key = f"{row['level_a']}_vs_{row['level_b']}"
            yaml_summary["jaccard_matrices"][key][pair_key] = {
                "jaccard": row["jaccard"],
                "overlap": row["overlap"],
                "union": row["union"],
            }

    for level in levels_found:
        count = sum(1 for v in level_specific if v["specific_to_level"] == level)
        yaml_summary["level_specific_variant_counts"][level] = count

    yaml_summary["total_level_specific_variants"] = len(level_specific)

    dump_yaml(yaml_summary, pathlib.Path(args.out_comparison))

    print(f"Jaccard matrix written to {args.out_jaccard}", file=sys.stderr)
    print(f"Level-specific variants written to {args.out_level_specific} ({len(level_specific)} variants)", file=sys.stderr)
    print(f"Comparison summary written to {args.out_comparison}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
