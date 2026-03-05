# Documentation Enhancement Suggestions for docs/output.md

## Additions Needed for Recent Features

### 1. Ablation Ranking Comparison (NEW Feature)

Add to the `ablation/` section:

```markdown
## Ablation Analysis Outputs

### Directory: `ablation/`

The ablation analysis trains models at different annotation levels (L0-L3) to assess the impact of annotation granularity on model performance.

#### Structure:
- `runs/` - Training outputs for each annotation level
  - `L0/` - Level 0 (basic functional annotations)
  - `L1/` - Level 1 (moderate annotations)
  - `L2/` - Level 2 (detailed annotations)
  - `L3/` - Level 3 (comprehensive annotations)
- `summary/`
  - **`ablation_summary.tsv`** - Performance metrics across all levels
  - **`ablation_summary.yaml`** - Structured summary with best level identification
  - **`ablation_ranking_comparison.yaml`** - ⭐ NEW: Variant ranking comparison metrics
  - **`ablation_jaccard_matrix.tsv`** - ⭐ NEW: Jaccard similarity between annotation levels
  - **`level_specific_variants.tsv`** - ⭐ NEW: Variants uniquely ranked high at each level

#### Key Outputs Explained:

**ablation_summary.tsv**
- Tab-separated metrics (AUC, accuracy, loss) for each annotation level
- Includes paths to full results for each level

**ablation_ranking_comparison.yaml**
- Jaccard similarity matrices comparing top-K variants across levels (K=50,100,200,500)
- Level-specific variant counts (variants highly ranked only at one level)
- Thresholds: high-rank (<100), low-rank (>500)

**ablation_jaccard_matrix.tsv**
- Pairwise Jaccard similarity between annotation levels
- Columns: `top_k`, `level_a`, `level_b`, `jaccard`, `overlap`, `size_a`, `size_b`, `union`
- Use to identify which levels produce similar vs. distinct variant priorities

**level_specific_variants.tsv**
- Variants that are highly ranked (top 100) at one annotation level but poorly ranked (>500) at others
- Columns: `variant_id`, `gene`, `chrom`, `pos`, `specific_to_level`, `rank_at_specific_level`, `rank_at_L0`, `rank_at_L1`, `rank_at_L2`, `rank_at_L3`, `mean_attribution_at_specific_level`
- **Interpretation**: These variants may represent annotation-level-specific biological signals
  - L0-specific: Might be driven by basic functional impact
  - L3-specific: May require comprehensive annotations to be prioritized

#### Use Cases:
1. **Assessing annotation value**: Compare performance metrics across levels to determine if richer annotations improve discovery
2. **Identifying robust variants**: High Jaccard similarity across levels suggests variants are robustly prioritized regardless of annotation complexity
3. **Finding annotation-dependent signals**: Level-specific variants indicate features that only emerge with certain annotation granularity
4. **Resource optimization**: If L1 performs nearly as well as L3, you might save computational resources
```

### 2. Plot Collection and Aggregation

Add a new section:

```markdown
## Plots and Visualizations

### Directory: `plots/`

All publication-ready plots generated throughout the pipeline are collected and organized in a central location.

#### Structure:
- `plots/` - Aggregated plot directory
  - `0001__*.png` - Sequentially numbered plot files
  - `0002__*.svg` - Multiple formats supported (PNG, SVG, PDF, EPS, TIFF)
  - ...
- `plots_manifest.tsv` - Index of all collected plots

#### plots_manifest.tsv Format:
```tsv
source_root	source_file	published_plot
data/preprocessed	data/preprocessed/phenotype_distribution.png	plots/0001__phenotype_distribution.png
explainability/analysis	explainability/analysis/top_genes_barplot.svg	plots/0002__top_genes_barplot.svg
ablation/summary	ablation/summary/performance_comparison.png	plots/0003__performance_comparison.png
```

#### Sources:
Plots are automatically collected from:
- Preprocessing diagnostics (sample distributions, quality metrics)
- Training convergence curves
- Explainability visualizations (gene rankings, variant impacts)
- Ablation performance comparisons
- Null baseline comparisons
- Discovery validation plots

#### Special Cases:
- If no plots are found, a placeholder file `0000__no_plots_found.txt` is created
- This ensures downstream processes complete successfully even when plot generation is skipped or fails
- Designed to work robustly with cloud storage backends (S3, GCS, Azure)

#### Usage Tips:
- Use `plots_manifest.tsv` to programmatically locate specific plot types
- Plot numbers are assigned in the order they're discovered (may vary between runs)
- Original filenames are preserved after the sequential number prefix for easy identification
```

### 3. Enhanced Null Baseline Section

Expand the existing `null_baseline/` section:

```markdown
## Null Baseline Comparison

### Directory: `null_baseline/`

The null baseline analysis creates permuted datasets to establish statistical significance of variant attributions.

#### Structure:
- `dataset/`
  - **`preprocessed_NULL.pt`** - Phenotype-permuted dataset (preserves genotypes)
- `train/`
  - Null model training artifacts (uses same hyperparameters as best model)
- `explain/`
  - `sieve_variant_rankings_NULL.csv` - Variant rankings from null model
  - `sieve_gene_rankings_NULL.csv` - Gene rankings from null model
  - Generated with `--is-null-baseline` flag
- `comparison/`
  - **`comparison_summary.yaml`** - Statistical comparison metrics
  - **`real_vs_null_attributions.tsv`** - Side-by-side attribution comparison
  - **`significant_variants.csv`** - Variants with attributions significantly higher than null
- `comparison_sex_chrom_fixed/` (if generated)
  - Same structure but with sex chromosome variants excluded from comparison

#### Interpretation:
- **Purpose**: Distinguish true biological signals from spurious correlations
- **Method**: Permute case/control labels → retrain → compare attributions
- **Significant variants**: Those with real attributions substantially exceeding null distribution
- **Expected behavior**: Null model should perform near-random (AUC ≈ 0.5); high attributions in null suggest overfitting or data leakage

#### Key Metrics in comparison_summary.yaml:
- `mean_attribution_real` vs `mean_attribution_null`
- `significant_variant_count` - Number of variants exceeding null baseline threshold
- `enrichment_ratio` - Fold-enrichment of high-attribution variants in real vs null
```

### 4. Output Block Documentation

Add a new section explaining the Nextflow output structure:

```markdown
## Nextflow Output Channels

The pipeline uses Nextflow's `output {}` block to organize results by category:

| Output Channel | Directory | Description |
|---------------|-----------|-------------|
| `sex_map` | `data/sex_map/` | Sex inference or user-provided sex mapping |
| `preprocessed_dataset` | `data/preprocessed/` | Encoded VCF data ready for training |
| `best_model` | `models/best_model/` | Best checkpoint and configuration |
| `explainability_best_model` | `explainability/best_model/` | Variant/gene attributions from best model |
| `explainability_analysis` | `explainability/analysis/` | Discovery validation and epistasis results |
| `ablation_discovery` | `ablation/discovery/` | Ablation training runs and performance comparison |
| `null_model` | `null/model/` | Null baseline training artifacts |
| `null_comparison` | `null/comparison/` | Real vs null attribution comparison |
| `null_comparison_sex_fixed` | `null/comparison_sex_chrom_fixed/` | Comparison excluding sex chromosomes |
| `plots` | `plots/` | All publication-ready visualizations |
| `pipeline_versions` | `pipeline_info/` | Software versions and execution metadata |

### Programmatic Access:
When running via Seqera Platform or with `-with-tower`, these outputs are published as named artifacts that can be:
- Downloaded individually
- Used as inputs for downstream analyses
- Tracked across workflow executions
- Shared with collaborators
```

### 5. Troubleshooting Section

Add a troubleshooting section:

```markdown
## Troubleshooting Output Issues

### Missing outputs
- **Symptom**: Expected output directory is empty
- **Cause**: Step may have been skipped due to `--execute_step` parameter or upstream artifact injection
- **Solution**: Check pipeline logs; verify you haven't provided shortcuts that skip steps (e.g., `--best_checkpoint` skips CV training)

### Empty plots directory
- **Symptom**: `plots/` contains only `0000__no_plots_found.txt`
- **Cause**: No plot files were generated by any process (may be expected in stub/test runs)
- **Solution**: Normal behavior when running with `-stub-run` or when plot generation is disabled

### Missing epistasis outputs
- **Symptom**: `epistasis/` directory doesn't exist
- **Cause**: Epistasis validation only runs when explainability finds gene-gene interactions
- **Solution**: Check `explainability/real/sieve_interactions.csv` - if empty/missing, epistasis is skipped (by design)

### Null baseline comparison incomplete
- **Symptom**: `null_baseline/comparison/` is missing
- **Cause**: Null training or explanation may have failed
- **Solution**: Check logs in `work/` directory for errors; verify preprocessed data is valid

### Version information missing
- **Symptom**: `pipeline_info/nf_core_sieve_software_versions.yml` is incomplete
- **Cause**: Some processes may have failed to emit versions
- **Solution**: Check execution report; versions from successful processes will still be recorded
```

### 6. File Format Specifications

Add detailed format documentation:

```markdown
## File Format Specifications

### sample_sex.tsv
```tsv
sample_id	sex	method	confidence
sample001	male	inferred	0.95
sample002	female	inferred	0.92
sample003	male	user_provided	1.00
```
- `sex`: male/female
- `method`: inferred (from chromosome ratios) or user_provided
- `confidence`: 0-1 score (1.0 for user-provided)

### best_params.yaml
```yaml
lr: 0.0001
lambda_attr: 0.1
latent_dim: 32
hidden_dim: 64
num_attention_layers: 1
annotation_level: L3
batch_size: 16
# ... additional training parameters
```
- Used to configure cross-validation training
- Can be provided via `--best_params` to skip grid search

### sieve_variant_rankings.csv
```csv
variant_id,gene,chrom,pos,ref,alt,mean_attribution,rank,annotation_level,phenotype_correlation
1:12345_A/T,GENE1,1,12345,A,T,0.85,1,L3,case-enriched
```
- Primary explainability output
- Ranked by mean_attribution (higher = more influential for prediction)
- Top-ranked variants are discovery candidates

### ablation_jaccard_matrix.tsv
```tsv
top_k	level_a	level_b	jaccard	overlap	size_a	size_b	union
50	L0	L1	0.35	21	50	50	60
100	L2	L3	0.60	67	100	100	112
```
- Jaccard similarity = overlap / union
- Higher values indicate similar variant rankings between levels
- Helps assess reproducibility across annotation complexity
```
