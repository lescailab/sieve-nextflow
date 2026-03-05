process SIEVE_ABLATION_RANKING_COMPARE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:f8e7db75b531e7d4' : 'ghcr.io/lescailab/sieve-container:f8e7db75b531e7d4'}"

    input:
    val meta
    path ranking_files

    output:
    tuple val(meta), path('ablation_ranking_comparison.yaml'), path('ablation_jaccard_matrix.tsv'), path('level_specific_variants.tsv'), emit: ranking_comparison
    path 'versions.yml', emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ablation_ranking_compare.py \
        --ranking-dir . \
        --top-k 50,100,200,500 \
        --high-rank-threshold 100 \
        --low-rank-threshold 500 \
        --out-comparison ablation_ranking_comparison.yaml \
        --out-jaccard ablation_jaccard_matrix.tsv \
        --out-level-specific level_specific_variants.tsv

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
    cat <<'EOF_YAML' > ablation_ranking_comparison.yaml
jaccard_matrices:
  top_50:
    L0_vs_L1: 0.35
    L0_vs_L2: 0.28
    L0_vs_L3: 0.22
    L1_vs_L2: 0.45
    L1_vs_L3: 0.38
    L2_vs_L3: 0.55
  top_100:
    L0_vs_L1: 0.40
    L0_vs_L2: 0.32
    L0_vs_L3: 0.27
    L1_vs_L2: 0.50
    L1_vs_L3: 0.43
    L2_vs_L3: 0.60
level_specific_variant_counts:
  L0: 12
  L1: 8
  L2: 5
  L3: 3
levels_analysed:
  - L0
  - L1
  - L2
  - L3
EOF_YAML

    cat <<'EOF_TSV' > ablation_jaccard_matrix.tsv
top_k	level_a	level_b	jaccard	overlap	size_a	size_b	union
50	L0	L1	0.3500	21	50	50	60
50	L0	L2	0.2800	18	50	50	64
50	L0	L3	0.2200	15	50	50	68
50	L1	L2	0.4500	28	50	50	62
50	L1	L3	0.3800	24	50	50	63
50	L2	L3	0.5500	34	50	50	62
100	L0	L1	0.4000	45	100	100	112
100	L0	L2	0.3200	38	100	100	119
100	L0	L3	0.2700	33	100	100	122
100	L1	L2	0.5000	57	100	100	114
100	L1	L3	0.4300	50	100	100	116
100	L2	L3	0.6000	67	100	100	112
EOF_TSV

    cat <<'EOF_LSV' > level_specific_variants.tsv
variant_id	gene	chrom	pos	specific_to_level	rank_at_specific_level	rank_at_L0	rank_at_L1	rank_at_L2	rank_at_L3	mean_attribution_at_specific_level
1:100_A/T	GENE1	1	100	L0	5	5	600	700	800	0.91
1:101_G/C	GENE2	1	101	L1	12	550	12	620	710	0.85
EOF_LSV

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
