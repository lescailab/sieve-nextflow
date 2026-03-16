process SIEVE_ABLATION_COMPARE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    val meta
    path run_dirs

    output:
    tuple val(meta), path('ablation_summary.tsv'), path('ablation_summary.yaml'), emit: ablation_summary
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def runDirs = run_dirs instanceof List ? run_dirs : [run_dirs]
    def runDirArgs = runDirs.collect { dir -> "--run-dir '${dir}'" }.join(' ')
    """
    ablation_compare.py \
        ${runDirArgs} \
        --out-summary-tsv ablation_summary.tsv \
        --out-summary-yaml ablation_summary.yaml

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
    cat <<'EOF_TSV' > ablation_summary.tsv
level	run_id	auc	accuracy	loss	results_yaml
L0	ablation_L0_selection_payload	0.69	0.61	0.58	/path/L0/results.yaml
L1	ablation_L1_selection_payload	0.73	0.65	0.55	/path/L1/results.yaml
L2	ablation_L2_selection_payload	0.77	0.69	0.52	/path/L2/results.yaml
L3	ablation_L3_selection_payload	0.81	0.73	0.49	/path/L3/results.yaml
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
  - level: L1
    run_id: ablation_L1_selection_payload
    auc: 0.73
    accuracy: 0.65
    loss: 0.55
  - level: L2
    run_id: ablation_L2_selection_payload
    auc: 0.77
    accuracy: 0.69
    loss: 0.52
  - level: L3
    run_id: ablation_L3_selection_payload
    auc: 0.81
    accuracy: 0.73
    loss: 0.49
EOF_YAML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
