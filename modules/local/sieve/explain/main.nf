process SIEVE_EXPLAIN {
    tag "$meta.id:${meta.run_id ?: 'explain'}"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(checkpoint), path(config), path(preprocessed), val(is_null_baseline)

    output:
    tuple val(meta), path('sieve_variant_rankings.csv'), path('sieve_gene_rankings.csv'), path('sieve_interactions.csv'), emit: rankings
    tuple val(meta), path('explain_output'), emit: explain_dir
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def nullFlag = is_null_baseline ? '--is-null-baseline' : ''
    """
    mkdir -p explain_output _exp_dir

    cp ${checkpoint} _exp_dir/best_model.pt
    cp ${config} _exp_dir/config.yaml

    sieve-explain \\
        --experiment-dir _exp_dir \\
        --preprocessed-data ${preprocessed} \\
        --output-dir explain_output \\
        ${nullFlag} \\
        ${args}

    variant_candidate=\$(find explain_output -maxdepth 3 -type f \\( -name 'sieve_variant_rankings.csv' -o -name '*variant*rank*.csv' \\) | head -n 1 || true)
    gene_candidate=\$(find explain_output -maxdepth 3 -type f \\( -name 'sieve_gene_rankings.csv' -o -name '*gene*rank*.csv' \\) | head -n 1 || true)
    interaction_candidate=\$(find explain_output -maxdepth 3 -type f \\( -name 'sieve_interactions.csv' -o -name '*interaction*.csv' \\) | head -n 1 || true)

    if [[ -n "\${variant_candidate}" ]]; then
        cp "\${variant_candidate}" sieve_variant_rankings.csv
    else
        cat <<'EOF_VARIANT' > sieve_variant_rankings.csv
variant_id,score
EOF_VARIANT
    fi

    if [[ -n "\${gene_candidate}" ]]; then
        cp "\${gene_candidate}" sieve_gene_rankings.csv
    else
        cat <<'EOF_GENE' > sieve_gene_rankings.csv
gene,score
EOF_GENE
    fi

    if [[ -n "\${interaction_candidate}" ]]; then
        cp "\${interaction_candidate}" sieve_interactions.csv
    else
        cat <<'EOF_INTERACTIONS' > sieve_interactions.csv
variant_a,variant_b,score
EOF_INTERACTIONS
    fi

    cp sieve_variant_rankings.csv explain_output/sieve_variant_rankings.csv
    cp sieve_gene_rankings.csv explain_output/sieve_gene_rankings.csv
    cp sieve_interactions.csv explain_output/sieve_interactions.csv

    sieve_version=\$(sieve-explain --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p explain_output

    cat <<'EOF_VARIANT' > sieve_variant_rankings.csv
variant_id,score
1:100_A/T,0.91
1:101_G/C,0.85
EOF_VARIANT

    cat <<'EOF_GENE' > sieve_gene_rankings.csv
gene,score
GENE1,0.88
GENE2,0.82
EOF_GENE

    if [[ "${is_null_baseline}" == "true" ]]; then
        cat <<'EOF_INTERACTIONS_NULL' > sieve_interactions.csv
variant_a,variant_b,score
EOF_INTERACTIONS_NULL
    else
        cat <<'EOF_INTERACTIONS' > sieve_interactions.csv
variant_a,variant_b,score
1:100_A/T,1:101_G/C,0.64
EOF_INTERACTIONS
    fi

    cp sieve_variant_rankings.csv explain_output/sieve_variant_rankings.csv
    cp sieve_gene_rankings.csv explain_output/sieve_gene_rankings.csv
    cp sieve_interactions.csv explain_output/sieve_interactions.csv
    touch explain_output/attributions.npz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
