process SIEVE_DOWNLOAD_REFERENCES {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    val(meta)
    val(genome_build)

    output:
    tuple val(meta), path('parsed_clinvar.tsv'), path('parsed_gwas.tsv'), path('parsed_go.json'), emit: references
    path 'versions.yml', emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    download_clinvar.py \
        --genome ${genome_build} \
        --output parsed_clinvar.tsv

    download_gwas_catalog.py \
        --genome ${genome_build} \
        --output parsed_gwas.tsv

    download_gene_ontology.py \
        --species human \
        --source goa \
        --output parsed_go.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
        pandas: \$(python -c 'import pandas; print(pandas.__version__)')
END_VERSIONS
    """

    stub:
    """
    echo -e "chrom\\tpos\\tref\\talt\\tgene\\tclinical_significance" > parsed_clinvar.tsv
    echo -e "1\\t12345\\tA\\tG\\tBRCA1\\tPathogenic" >> parsed_clinvar.tsv

    echo -e "gene\\tdisease_trait\\tchr\\tpos\\tsnp_id\\tp_value\\trisk_allele" > parsed_gwas.tsv
    echo -e "BRCA1\\tBreast cancer\\t17\\t41234000\\trs80357906\\t1e-20\\tA" >> parsed_gwas.tsv

    echo '{"BRCA1": ["GO:0006281", "GO:0006974"]}' > parsed_go.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
        pandas: "stub"
END_VERSIONS
    """
}
