process SIEVE_VALIDATE_DISCOVERIES {
    tag "$meta.id:${meta.run_id ?: 'validate_discoveries'}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(variant_rankings), path(gene_rankings), path(clinvar_tsv), path(gwas_tsv), path(go_mapping_json)

    output:
    tuple val(meta), path('validation_report.yaml'), path('validation_output'), emit: validation
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def advancedArgs = []
    if (clinvar_tsv) {
        advancedArgs << "--clinvar ${clinvar_tsv}"
    }
    if (gwas_tsv) {
        advancedArgs << "--gwas ${gwas_tsv}"
    }
    if (go_mapping_json) {
        advancedArgs << "--go-mapping ${go_mapping_json}"
    }
    def advancedArgString = advancedArgs.join(' ')

    """
    mkdir -p validation_output

    sieve-validate-discoveries \
        --variant-rankings ${variant_rankings} \
        --gene-rankings ${gene_rankings} \
        --output-dir validation_output \
        ${advancedArgString} \
        ${args}

    report_candidate=\$(find validation_output -maxdepth 3 -type f \\( -name 'validation_report.yaml' -o -name '*validation*report*.yaml' \\) | head -n 1 || true)

    if [[ -n "\${report_candidate}" ]]; then
        cp "\${report_candidate}" validation_report.yaml
    else
        cat <<'EOF_VALIDATION' > validation_report.yaml
validated_variants: 0
validated_genes: 0
sources: []
EOF_VALIDATION
    fi

    cp validation_report.yaml validation_output/validation_report.yaml

    sieve_version=\$(sieve-validate-discoveries --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p validation_output

    cat <<'EOF_VALIDATION' > validation_report.yaml
validated_variants: 2
validated_genes: 1
sources:
  - clinvar
  - gwas
EOF_VALIDATION

    cp validation_report.yaml validation_output/validation_report.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
