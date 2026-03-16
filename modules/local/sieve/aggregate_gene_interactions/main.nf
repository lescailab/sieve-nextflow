process SIEVE_AGGREGATE_GENE_INTERACTIONS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    tuple val(meta), path(preprocessed), path(variant_rankings), path(gene_rankings)
    path null_rankings, stageAs: 'null_sieve_variant_rankings.csv'
    path cooccurrence_pairs

    output:
    tuple val(meta), path('gene_interactions_output'), path('gene_pair_interactions.csv'), emit: gene_interactions
    tuple val(meta), path('gene_interaction_network_edges.csv'), path('gene_interaction_network_nodes.csv'), emit: network
    path 'versions.yml', emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def null_arg = null_rankings ? "--null-rankings ${null_rankings}" : ''
    def cooccur_arg = cooccurrence_pairs ? "--cooccurrence ${cooccurrence_pairs}" : ''
    """
    mkdir -p gene_interactions_output

    sieve-aggregate-gene-interactions \
        --preprocessed-data ${preprocessed} \
        --variant-rankings ${variant_rankings} \
        --gene-rankings ${gene_rankings} \
        --output-dir gene_interactions_output \
        ${null_arg} \
        ${cooccur_arg} \
        ${args}

    # Copy key outputs to working directory for explicit emission
    cp gene_interactions_output/gene_pair_interactions.csv gene_pair_interactions.csv
    cp gene_interactions_output/gene_interaction_network_edges.csv gene_interaction_network_edges.csv
    cp gene_interactions_output/gene_interaction_network_nodes.csv gene_interaction_network_nodes.csv

    sieve_version=\$(sieve-aggregate-gene-interactions --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p gene_interactions_output

    cat <<'EOF_PAIRS' > gene_pair_interactions.csv
gene_a,gene_b,n_cooccur,interaction_score,gene_score_a,gene_score_b
BRCA1,TP53,15,2.34,0.91,0.88
EOF_PAIRS

    cat <<'EOF_EDGES' > gene_interaction_network_edges.csv
gene_a,gene_b,weight,n_cooccur
BRCA1,TP53,2.34,15
EOF_EDGES

    cat <<'EOF_NODES' > gene_interaction_network_nodes.csv
gene,degree,gene_score,gene_rank,n_partners
BRCA1,3,0.91,1,3
TP53,2,0.88,2,2
EOF_NODES

    cat <<'EOF_YAML' > gene_interactions_output/gene_interaction_summary.yaml
n_gene_pairs: 10
n_genes_in_network: 8
EOF_YAML

    cp gene_pair_interactions.csv gene_interactions_output/gene_pair_interactions.csv
    cp gene_interaction_network_edges.csv gene_interactions_output/gene_interaction_network_edges.csv
    cp gene_interaction_network_nodes.csv gene_interactions_output/gene_interaction_network_nodes.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
