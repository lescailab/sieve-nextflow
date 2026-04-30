process SIEVE_ABLATION_COMPARE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:803e8d8c7e63be61' : 'ghcr.io/lescailab/sieve-container:803e8d8c7e63be61'}"

    input:
    val meta
    path run_dirs

    output:
    tuple val(meta), path('ablation_summary.tsv'), path('ablation_summary.yaml'), emit: ablation_summary
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-ablation-compare \\
        --results-dir . \\
        --out-summary-tsv ablation_summary.tsv \\
        --out-summary-yaml ablation_summary.yaml \\
        ${args}

    sieve_version=\$(sieve-ablation-compare --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    cat <<'EOF_TSV' > ablation_summary.tsv
level\trun_id\tauc\taccuracy\tloss\tresults_yaml
L0\tablation_L0_selection_payload\t0.69\t0.61\t0.58\t/path/L0/results.yaml
L1\tablation_L1_selection_payload\t0.73\t0.65\t0.55\t/path/L1/results.yaml
L2\tablation_L2_selection_payload\t0.77\t0.69\t0.52\t/path/L2/results.yaml
L3\tablation_L3_selection_payload\t0.81\t0.73\t0.49\t/path/L3/results.yaml
EOF_TSV

    cat <<'EOF_YAML' > ablation_summary.yaml
best_level: L3
best_run_id: ablation_L3_selection_payload
ranking_metric_priority:
  - auc
  - accuracy
  - loss
levels:
  - level: L0
    run_id: ablation_L0_selection_payload
    auc: 0.69
    accuracy: 0.61
    loss: 0.58
  - level: L3
    run_id: ablation_L3_selection_payload
    auc: 0.81
    accuracy: 0.73
    loss: 0.49
EOF_YAML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
