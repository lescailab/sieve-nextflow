#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<USAGE
Usage:
  sieve_cmd.sh <subcommand> [arguments...]

Subcommands:
  infer_sex
  preprocess
  train
  explain
  create_null_baseline
  compare_attributions
  validate_epistasis
  validate_discoveries

Options:
  --version     Print the installed SIEVE package version when detectable
  --help        Show this help
USAGE
}

resolve_python_module() {
    local module="$1"
    python -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('${module}') else 1)" >/dev/null 2>&1
}

print_version() {
    local candidate
    for candidate in sieve-train sieve-preprocess sieve-explain; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            "${candidate}" --version 2>/dev/null || true
            return 0
        fi
    done

    python -c "
import sys
try:
    from importlib import metadata as md
except ImportError:
    import importlib_metadata as md
for name in ('sieve', 'lescailab-sieve'):
    try:
        print(md.version(name))
        sys.exit(0)
    except Exception:
        pass
sys.exit(1)
" 2>/dev/null || {
        echo "unknown"
        return 0
    }
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

case "$1" in
    --help|-h)
        usage
        exit 0
        ;;
    --version)
        print_version
        exit 0
        ;;
esac

subcommand="$1"
shift

binary_candidates=()
python_candidates=()

case "${subcommand}" in
    infer_sex)
        binary_candidates=("sieve-infer-sex" "sieve-infer_sex")
        python_candidates=("sieve.scripts.infer_sex")
        ;;
    preprocess)
        binary_candidates=("sieve-preprocess")
        python_candidates=("sieve.scripts.preprocess")
        ;;
    train)
        binary_candidates=("sieve-train")
        python_candidates=("sieve.scripts.train")
        ;;
    explain)
        binary_candidates=("sieve-explain")
        python_candidates=("sieve.scripts.explain")
        ;;
    create_null_baseline)
        binary_candidates=("sieve-create-null-baseline" "sieve-create_null_baseline")
        python_candidates=("sieve.scripts.create_null_baseline")
        ;;
    compare_attributions)
        binary_candidates=("sieve-compare-attributions" "sieve-compare_attributions")
        python_candidates=("sieve.scripts.compare_attributions")
        ;;
    validate_epistasis)
        binary_candidates=("sieve-validate-epistasis" "sieve-validate_epistasis")
        python_candidates=("sieve.scripts.validate_epistasis")
        ;;
    validate_discoveries)
        binary_candidates=("sieve-validate-discoveries" "sieve-validate_discoveries")
        python_candidates=("sieve.scripts.validate_discoveries")
        ;;
    *)
        echo "ERROR: Unsupported subcommand '${subcommand}'" >&2
        usage
        exit 2
        ;;
esac

for cmd in "${binary_candidates[@]}"; do
    if command -v "${cmd}" >/dev/null 2>&1; then
        exec "${cmd}" "$@"
    fi
done

if command -v sieve >/dev/null 2>&1; then
    exec sieve "${subcommand}" "$@"
fi

for module in "${python_candidates[@]}"; do
    if resolve_python_module "${module}"; then
        exec python -m "${module}" "$@"
    fi
done

echo "ERROR: Could not find SIEVE command for subcommand '${subcommand}'." >&2
echo "Tried binaries: ${binary_candidates[*]} and Python modules: ${python_candidates[*]}" >&2
exit 127
