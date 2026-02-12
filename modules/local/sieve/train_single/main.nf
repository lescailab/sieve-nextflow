process SIEVE_TRAIN_SINGLE {
    tag "$meta.id:${meta.run_id ?: 'run'}:${level}"
    label 'process_medium'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(preprocessed), path(sex_map), val(train_params), val(level), val(val_split)

    output:
    tuple val(meta), path('results.yaml'), path('config.yaml'), path('best_model.pt'), emit: train_artifacts
    tuple val(meta), path('training_history.yaml'), optional: true, emit: history
    tuple val(meta), path('*_selection_payload'), emit: selection_payload
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    def runIdRaw = meta.run_id ?: (train_params instanceof Map ? train_params.run_id : null) ?: 'run'
    def runId = runIdRaw.toString().replaceAll(/[^A-Za-z0-9_.-]/, '_')
    def trainParamMap = train_params instanceof Map ? train_params : [:]
    def trainParamArgs = trainParamMap
        .findAll { key, value ->
            value != null && !(key.toString() in ['run_id', 'stage', 'level'])
        }
        .collect { key, value ->
            def cliKey = key.toString().replaceAll('_', '-')
            def cliValue = value instanceof String ? "\"${value}\"" : value.toString()
            "--${cliKey} ${cliValue}"
        }
        .join(' ')

    """
    mkdir -p train_output

    sieve_cmd.sh train \
        --preprocessed-data ${preprocessed} \
        --sex-map ${sex_map} \
        --output-dir train_output \
        --annotation-level ${level} \
        --val-split ${val_split} \
        ${trainParamArgs} \
        ${args}

    results_candidate=\$(find train_output -maxdepth 3 -type f \( -name 'results.yaml' -o -name '*results*.yaml' \) | head -n 1 || true)
    config_candidate=\$(find train_output -maxdepth 3 -type f \( -name 'config.yaml' -o -name '*config*.yaml' \) | head -n 1 || true)
    model_candidate=\$(find train_output -maxdepth 5 -type f \( -name 'best_model.pt' -o -name '*checkpoint*.pt' -o -name '*.pt' \) | head -n 1 || true)

    [[ -n "\${results_candidate}" ]] || { echo "ERROR: Missing training results YAML" >&2; exit 1; }
    [[ -n "\${config_candidate}" ]] || { echo "ERROR: Missing training config YAML" >&2; exit 1; }
    [[ -n "\${model_candidate}" ]] || { echo "ERROR: Missing training model checkpoint" >&2; exit 1; }

    cp "\${results_candidate}" results.yaml
    cp "\${config_candidate}" config.yaml
    cp "\${model_candidate}" best_model.pt

    history_candidate=\$(find train_output -maxdepth 3 -type f -name '*history*.yaml' | head -n 1 || true)
    if [[ -n "\${history_candidate}" ]]; then
        cp "\${history_candidate}" training_history.yaml
    fi

    mkdir -p ${runId}_selection_payload
    cp results.yaml ${runId}_selection_payload/results.yaml
    cp config.yaml ${runId}_selection_payload/config.yaml
    cp best_model.pt ${runId}_selection_payload/best_model.pt

    sieve_version=\$(sieve_cmd.sh --version 2>/dev/null | head -n 1 || true)
    [[ -z "\${sieve_version}" ]] && sieve_version="unknown"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
    END_VERSIONS
    """

    stub:
    def runIdRawStub = meta.run_id ?: (train_params instanceof Map ? train_params.run_id : null) ?: 'run'
    def runIdStub = runIdRawStub.toString().replaceAll(/[^A-Za-z0-9_.-]/, '_')
    def trainParamMapStub = train_params instanceof Map ? train_params : [:]
    """
    mkdir -p train_output

    run_idx=\$(echo "${runIdStub}" | tr -cd '0-9' | head -c 3)
    [[ -z "\${run_idx}" ]] && run_idx=1

    auc=\$(awk -v idx="\${run_idx}" -v lvl="${level}" 'BEGIN{base=0.80; if(lvl=="L0")base=0.68; if(lvl=="L1")base=0.72; if(lvl=="L2")base=0.76; if(lvl=="L3")base=0.80; printf "%.4f", base + (idx % 7)/200.0}')
    acc=\$(awk -v idx="\${run_idx}" -v lvl="${level}" 'BEGIN{base=0.70; if(lvl=="L0")base=0.60; if(lvl=="L1")base=0.64; if(lvl=="L2")base=0.68; if(lvl=="L3")base=0.72; printf "%.4f", base + (idx % 5)/200.0}')
    loss=\$(awk -v idx="\${run_idx}" 'BEGIN{printf "%.4f", 0.60 - (idx % 6)/200.0}')

    cat <<EOF_STUB_RESULTS > results.yaml
metrics:
  auc: \${auc}
  accuracy: \${acc}
  loss: \${loss}
EOF_STUB_RESULTS

    cat <<EOF_STUB_CONFIG > config.yaml
hyperparameters:
  lr: ${trainParamMapStub.lr ?: 0.0001}
  lambda_attr: ${trainParamMapStub.lambda_attr ?: 0.1}
  batch_size: ${trainParamMapStub.batch_size ?: 8}
  chunk_size: ${trainParamMapStub.chunk_size ?: 2000}
  aggregation_method: "${trainParamMapStub.aggregation_method ?: 'mean'}"
  annotation_level: "${level}"
  val_split: ${val_split}
EOF_STUB_CONFIG

    touch best_model.pt

    cat <<EOF_STUB_HISTORY > training_history.yaml
epochs:
  - epoch: 1
    auc: \${auc}
    accuracy: \${acc}
    loss: \${loss}
EOF_STUB_HISTORY

    mkdir -p ${runIdStub}_selection_payload
    cp results.yaml ${runIdStub}_selection_payload/results.yaml
    cp config.yaml ${runIdStub}_selection_payload/config.yaml
    cp best_model.pt ${runIdStub}_selection_payload/best_model.pt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
    END_VERSIONS
    """
}
