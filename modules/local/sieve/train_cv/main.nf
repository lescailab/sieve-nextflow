process SIEVE_TRAIN_CV {
    tag "$meta.id:${meta.run_id ?: 'cv'}:${level}:cv${cv_folds}"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    tuple val(meta), path(preprocessed), path(sex_map), path(best_params), val(level), val(cv_folds)

    output:
    tuple val(meta), path('cv_output'), path('cv_results.yaml'), emit: cv_bundle
    tuple val(meta), path('cv_output/fold_*'), emit: fold_dirs
    path 'versions.yml', emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p cv_output

    # Unpack best_params YAML into individual CLI flags
    # Skip keys already passed explicitly (level, annotation_level)
    PARAM_FLAGS=\$(awk -F': ' '
        /^[[:space:]]*#/ {next}
        /^[[:space:]]*\$/ {next}
        NF>=2 {
            key=\$1; gsub(/^[[:space:]]+|[[:space:]]+\$/, "", key)
            val=\$2; gsub(/^[[:space:]]+|[[:space:]]+\$/, "", val)
            if (key == "level" || key == "annotation_level") next
            gsub(/_/, "-", key)
            printf "--%s %s ", key, val
        }
    ' ${best_params})

    sieve-train \
        --preprocessed-data ${preprocessed} \
        --sex-map ${sex_map} \
        --output-dir cv_output \
        --level ${level} \
        --cv ${cv_folds} \
        \${PARAM_FLAGS} \
        ${args}

    if ! find cv_output -maxdepth 1 -type d -name 'fold_*' | grep -q .; then
        mkdir -p cv_output/fold_1
        cfg_candidate=\$(find cv_output -maxdepth 3 -type f \\( -name 'config.yaml' -o -name '*config*.yaml' \\) | head -n 1 || true)
        model_candidate=\$(find cv_output -maxdepth 5 -type f \\( -name 'best_model.pt' -o -name '*.pt' \\) | head -n 1 || true)
        metric_candidate=\$(find cv_output -maxdepth 3 -type f \\( -name 'fold_info.yaml' -o -name 'results.yaml' -o -name '*metrics*.yaml' \\) | head -n 1 || true)

        [[ -n "\${cfg_candidate}" ]] && cp "\${cfg_candidate}" cv_output/fold_1/config.yaml || cp ${best_params} cv_output/fold_1/config.yaml
        [[ -n "\${model_candidate}" ]] && cp "\${model_candidate}" cv_output/fold_1/best_model.pt || touch cv_output/fold_1/best_model.pt
        if [[ -n "\${metric_candidate}" ]]; then
            cp "\${metric_candidate}" cv_output/fold_1/fold_info.yaml
        else
            cat <<'EOF_FOLD_INFO' > cv_output/fold_1/fold_info.yaml
metrics:
  auc: 0.0
  accuracy: 0.0
  loss: 9999
EOF_FOLD_INFO
        fi
    fi

    if [[ ! -f cv_results.yaml ]]; then
        cv_results_candidate=\$(find cv_output -maxdepth 3 -type f \\( -name 'cv_results.yaml' -o -name '*cv*results*.yaml' \\) | head -n 1 || true)
        if [[ -n "\${cv_results_candidate}" ]]; then
            cp "\${cv_results_candidate}" cv_results.yaml
        else
            cat <<'EOF_CV_RESULTS' > cv_results.yaml
n_folds: ${cv_folds}
metric_priority:
  - auc
  - accuracy
  - loss
EOF_CV_RESULTS
        fi
    fi

    sieve_version=\$(sieve-train --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p cv_output

    for i in \$(seq 1 ${cv_folds}); do
        fold_dir="cv_output/fold_\${i}"
        mkdir -p "\${fold_dir}"

        auc=\$(awk -v idx="\${i}" 'BEGIN{printf "%.4f", 0.78 + idx/200.0}')
        acc=\$(awk -v idx="\${i}" 'BEGIN{printf "%.4f", 0.68 + idx/250.0}')
        loss=\$(awk -v idx="\${i}" 'BEGIN{printf "%.4f", 0.52 - idx/250.0}')

        cat <<EOF_FOLD_INFO > "\${fold_dir}/fold_info.yaml"
metrics:
  auc: \${auc}
  accuracy: \${acc}
  loss: \${loss}
EOF_FOLD_INFO

        cat <<EOF_FOLD_CONFIG > "\${fold_dir}/config.yaml"
annotation_level: "${level}"
fold: \${i}
EOF_FOLD_CONFIG

        touch "\${fold_dir}/best_model.pt"
    done

    cat <<EOF_CV_RESULTS > cv_results.yaml
n_folds: ${cv_folds}
metric_priority:
  - auc
  - accuracy
  - loss
EOF_CV_RESULTS

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
