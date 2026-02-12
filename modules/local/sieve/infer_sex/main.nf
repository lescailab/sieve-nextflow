process SIEVE_INFER_SEX {
    tag "$meta.id"
    label 'process_medium'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(vcf)
    val genome_build

    output:
    tuple val(meta), path('sample_sex.tsv'), emit: sex_map
    tuple val(meta), path('infer_sex_diagnostics/*'), optional: true, emit: diagnostics
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p infer_sex_diagnostics

    sieve_cmd.sh infer_sex \
        --vcf ${vcf} \
        --output-dir infer_sex_diagnostics \
        --genome-build ${genome_build} \
        ${args}

    sex_map_candidate=""
    if [[ -f infer_sex_diagnostics/sample_sex.tsv ]]; then
        sex_map_candidate="infer_sex_diagnostics/sample_sex.tsv"
    else
        sex_map_candidate=\$(find infer_sex_diagnostics -maxdepth 2 -type f -name '*sex*.tsv' | head -n 1 || true)
    fi

    if [[ -z "\${sex_map_candidate}" ]]; then
        echo "ERROR: SIEVE infer_sex did not produce a sex map TSV" >&2
        exit 1
    fi

    cp "\${sex_map_candidate}" sample_sex.tsv

    sieve_version=\$(sieve_cmd.sh --version 2>/dev/null | head -n 1 || true)
    [[ -z "\${sieve_version}" ]] && sieve_version="unknown"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p infer_sex_diagnostics

    cat <<'EOF_STUB_SEX' > sample_sex.tsv
sample_id	sex
sampleA	female
sampleB	male
EOF_STUB_SEX

    cp sample_sex.tsv infer_sex_diagnostics/sample_sex.tsv
    touch infer_sex_diagnostics/sex_inference_plot.png

    cat <<'EOF_STUB_SUMMARY' > infer_sex_diagnostics/sex_inference_summary.yaml
n_samples: 2
n_female: 1
n_male: 1
EOF_STUB_SUMMARY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
