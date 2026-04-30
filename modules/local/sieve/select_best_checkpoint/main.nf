process SIEVE_SELECT_BEST_CHECKPOINT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:803e8d8c7e63be61' : 'ghcr.io/lescailab/sieve-container:803e8d8c7e63be61'}"

    input:
    tuple val(meta), path(cv_output), path(cv_results)

    output:
    tuple val(meta), path('best_checkpoint.pt'), path('best_fold_config.yaml'), path('best_fold_id.txt'), path('cv_folds_summary.tsv'), emit: best_checkpoint
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    fold_dirs=\$(find ${cv_output}/ -mindepth 1 -maxdepth 1 -type d -name 'fold_*' | sort)

    if [ -z "\${fold_dirs}" ]; then
        echo "ERROR: No fold directories found in ${cv_output}" >&2
        exit 1
    fi

    set --
    for fold_dir in \${fold_dirs}; do
        set -- "\$@" --fold-dir "\${fold_dir}"
    done

    select_best_cv_fold.py \
        "\$@" \
        --out-best-checkpoint best_checkpoint.pt \
        --out-best-config best_fold_config.yaml \
        --out-best-fold-id best_fold_id.txt \
        --out-summary cv_folds_summary.tsv

    python - <<'PY' > .python_version.tmp
import sys
print(f'python: "{sys.version.split()[0]}"')
PY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        \$(cat .python_version.tmp)
END_VERSIONS
    """

    stub:
    """
    touch best_checkpoint.pt

    cat <<'EOF_CONFIG' > best_fold_config.yaml
annotation_level: L3
fold: 2
EOF_CONFIG

    echo "fold_2" > best_fold_id.txt

    cat <<'EOF_SUMMARY' > cv_folds_summary.tsv
fold_id	auc	accuracy	loss	metrics_yaml	config_yaml	checkpoint
fold_2	0.83	0.74	0.49	/path/fold_2/fold_info.yaml	/path/fold_2/config.yaml	/path/fold_2/best_model.pt
fold_1	0.81	0.73	0.52	/path/fold_1/fold_info.yaml	/path/fold_1/config.yaml	/path/fold_1/best_model.pt
EOF_SUMMARY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
