process SIEVE_SELECT_BEST_CHECKPOINT {
    tag "$meta.id"
    label 'process_low'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(cv_output), path(cv_results)

    output:
    tuple val(meta), path('best_checkpoint.pt'), path('best_fold_config.yaml'), path('best_fold_id.txt'), path('cv_folds_summary.tsv'), emit: best_checkpoint
    path 'versions.yml', emit: versions

    script:
    """
    mapfile -t fold_dirs < <(find ${cv_output} -mindepth 1 -maxdepth 1 -type d -name 'fold_*' | sort)

    if [[ \${#fold_dirs[@]} -eq 0 ]]; then
        echo "ERROR: No fold directories found in ${cv_output}" >&2
        exit 1
    fi

    fold_args=()
    for fold_dir in "\${fold_dirs[@]}"; do
        fold_args+=("--fold-dir" "\${fold_dir}")
    done

    select_best_cv_fold.py \
        "\${fold_args[@]}" \
        --out-best-checkpoint best_checkpoint.pt \
        --out-best-config best_fold_config.yaml \
        --out-best-fold-id best_fold_id.txt \
        --out-summary cv_folds_summary.tsv

    python --version | sed 's/Python //g' | awk '{print "python: \"" $1 "\""}' > .python_version.tmp

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
