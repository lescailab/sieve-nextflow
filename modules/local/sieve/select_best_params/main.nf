process SIEVE_SELECT_BEST_PARAMS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:f8e7db75b531e7d4' : 'ghcr.io/lescailab/sieve-container:f8e7db75b531e7d4'}"

    input:
    val meta
    path run_dirs

    output:
    tuple val(meta), path('best_params.yaml'), path('best_run_id.txt'), path('train_grid_summary.tsv'), emit: best_params
    path 'versions.yml', emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def runDirs = run_dirs instanceof List ? run_dirs : [run_dirs]
    def runDirArgs = runDirs.collect { "--run-dir '${it}'" }.join(' ')
    """
    select_best_train_params.py \
        ${runDirArgs} \
        --out-best-params best_params.yaml \
        --out-best-run-id best_run_id.txt \
        --out-summary train_grid_summary.tsv

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
    cat <<'EOF_BEST' > best_params.yaml
lr: 0.0001
lambda_attr: 0.1
latent_dim: 32
hidden_dim: 64
num_attention_layers: 1
batch_size: 16
chunk_size: 3000
aggregation_method: mean
epochs: 100
gradient_accumulation_steps: 4
gradient_clip: 1.0
seed: 42
device: cuda
early_stopping: 10
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
