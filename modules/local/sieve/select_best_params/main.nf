process SIEVE_SELECT_BEST_PARAMS {
    tag "$meta.id"
    label 'process_low'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    val meta
    path run_dirs

    output:
    tuple val(meta), path('best_params.yaml'), path('best_run_id.txt'), path('train_grid_summary.tsv'), emit: best_params
    path 'versions.yml', emit: versions

    script:
    def runDirs = run_dirs instanceof List ? run_dirs : [run_dirs]
    def runDirArgs = runDirs.collect { "--run-dir '${it}'" }.join(' ')
    """
    select_best_train_params.py \
        ${runDirArgs} \
        --out-best-params best_params.yaml \
        --out-best-run-id best_run_id.txt \
        --out-summary train_grid_summary.tsv

    python -c 'import sys; print(f"python: \"{sys.version.split()[0]}\"")' > .python_version.tmp

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        \$(cat .python_version.tmp)
END_VERSIONS
    """

    stub:
    """
    cat <<'EOF_BEST' > best_params.yaml
aggregation_method: mean
batch_size: 8
chunk_size: 2000
lambda_attr: 0.1
lr: 0.0001
annotation_level: L3
EOF_BEST

    echo "grid_001_selection_payload" > best_run_id.txt

    cat <<'EOF_SUMMARY' > train_grid_summary.tsv
run_id	auc	accuracy	loss	results_yaml	config_yaml
grid_001_selection_payload	0.82	0.73	0.51	/path/results.yaml	/path/config.yaml
EOF_SUMMARY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
