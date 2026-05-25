//
// Subworkflow: Ablation analysis — train per-level models, explain, per-level null comparison,
//              generate gene lists, compare rankings, and plot comparison
//

include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_ABLATION           } from '../../../modules/local/sieve/train_single/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_NULL_ABLATION      } from '../../../modules/local/sieve/train_single/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_ABLATION                     } from '../../../modules/local/sieve/explain/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_NULL_ABLATION                } from '../../../modules/local/sieve/explain/main'
include { SIEVE_ABLATION_COMPARE                                       } from '../../../modules/local/sieve/ablation_compare/main'
include { SIEVE_ABLATION_RANKING_COMPARE                               } from '../../../modules/local/sieve/ablation_ranking_compare/main'
include { SIEVE_COMPARE_ATTRIBUTIONS as SIEVE_COMPARE_ATTRIBUTIONS_ABL } from '../../../modules/local/sieve/compare_attributions/main'
include { SIEVE_BOOTSTRAP_NULL_CALIBRATION as SIEVE_BOOTSTRAP_ABL      } from '../../../modules/local/sieve/bootstrap_null_calibration/main'
include { SIEVE_CORRECT_CHRX_BIAS as SIEVE_CORRECT_CHRX_BIAS_ABL       } from '../../../modules/local/sieve/correct_chrx_bias/main'
include { SIEVE_PLOT_ABLATION_COMPARISON                               } from '../../../modules/local/sieve/plot_ablation_comparison/main'
include { SIEVE_GENERATE_GENE_LIST                                     } from '../../../modules/local/sieve/generate_gene_list/main'

workflow ABLATION {

    take:
    ch_selection_meta          // channel: val([id: cohort_id])
    ch_preprocessed_keyed      // channel: [ val(cohort_id), path(preprocessed) ]
    ch_sex_map_keyed           // channel: [ val(cohort_id), path(sex_map) ]
    ch_best_params_map_keyed   // channel: [ val(cohort_id), val(params_map) ]
    ch_null_preprocessed_keyed // channel: [ val(cohort_id), path(preprocessed_null) ]

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']

    def baseTrainingParams = [
        epochs: params.train_epochs as Integer,
        batch_size: params.train_batch_size as Integer,
        chunk_size: params.train_chunk_size as Integer,
        chunk_overlap: params.train_chunk_overlap as Integer,
        aggregation_method: params.train_aggregation_method,
        gradient_accumulation_steps: params.train_gradient_accumulation_steps as Integer,
        gradient_clip: params.train_gradient_clip as Double,
        seed: params.train_seed as Integer,
        device: params.train_device,
        early_stopping: params.train_early_stopping as Integer,
        hidden_dim: params.train_hidden_dim as Integer,
        num_attention_layers: params.train_num_attention_layers as Integer,
        num_heads: params.train_num_heads != null ? (params.train_num_heads as Integer) : null,
        classifier_type: params.train_classifier_type,
        class_weighting: params.train_class_weighting,
        num_pcs: params.num_pcs != null ? (params.num_pcs as Integer) : null,
    ].findAll { _key, value -> value != null }

    ch_ablation_specs = channel
        .fromList(['L0', 'L1', 'L2', 'L3'])
        .map { level ->
            tuple(
                cohortMeta.id,
                [id: cohortMeta.id, run_id: "ablation_${level}", stage: 'ablation', level: level],
                level,
                params.val_split
            )
        }

    // -----------------------------------------------------------------------
    // Real ablation training and explainability
    // -----------------------------------------------------------------------

    ch_ablation_train_input = ch_ablation_specs
        .combine(ch_preprocessed_keyed, by: 0)
        .combine(ch_sex_map_keyed, by: 0)
        .combine(ch_best_params_map_keyed, by: 0)
        .map { _key, meta, level, val_split, preprocessed, sex_map, best_params_map ->
            def ablationParams = new LinkedHashMap(baseTrainingParams)
            ablationParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
            ablationParams.put('annotation_level', level)
            tuple(meta, preprocessed, sex_map, ablationParams, level, val_split)
        }

    SIEVE_TRAIN_SINGLE_ABLATION(ch_ablation_train_input)
    ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.versions)
    ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { _meta, run_dir -> run_dir })

    // Metrics comparison across levels
    ch_ablation_selection_dirs = SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload
        .map { _meta, run_dir -> run_dir }
        .collect()

    SIEVE_ABLATION_COMPARE(
        ch_selection_meta,
        ch_ablation_selection_dirs
    )
    ch_versions = ch_versions.mix(SIEVE_ABLATION_COMPARE.out.versions)

    // Explain each ablation level
    ch_ablation_explain_input = SIEVE_TRAIN_SINGLE_ABLATION.out.train_artifacts
        .map { meta, _results, config, checkpoint ->
            tuple(meta, checkpoint, config)
        }
        .combine(ch_preprocessed_keyed.map { _cohort_id, preprocessed -> preprocessed })
        .map { meta, checkpoint, config, preprocessed ->
            tuple(
                [id: meta.id, run_id: "explain_ablation_${meta.level}", stage: 'ablation', level: meta.level],
                checkpoint,
                config,
                preprocessed,
                false
            )
        }

    SIEVE_EXPLAIN_ABLATION(ch_ablation_explain_input)
    ch_versions = ch_versions.mix(SIEVE_EXPLAIN_ABLATION.out.versions)

    // -----------------------------------------------------------------------
    // Per-level null training and explainability (reuse null preprocessed data)
    // -----------------------------------------------------------------------

    ch_null_ablation_train_input = ch_ablation_specs
        .combine(ch_null_preprocessed_keyed, by: 0)
        .combine(ch_sex_map_keyed, by: 0)
        .combine(ch_best_params_map_keyed, by: 0)
        .map { _key, meta, level, val_split, preprocessed_null, sex_map, best_params_map ->
            def nullParams = new LinkedHashMap(baseTrainingParams)
            nullParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
            nullParams.put('annotation_level', level)
            tuple(
                [id: meta.id, run_id: "null_ablation_${level}", stage: 'ablation_null', level: level],
                preprocessed_null,
                sex_map,
                nullParams,
                level,
                val_split
            )
        }

    SIEVE_TRAIN_SINGLE_NULL_ABLATION(ch_null_ablation_train_input)
    ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_NULL_ABLATION.out.versions)

    ch_null_ablation_explain_input = SIEVE_TRAIN_SINGLE_NULL_ABLATION.out.train_artifacts
        .map { meta, _results, config, checkpoint ->
            tuple(meta, checkpoint, config)
        }
        .combine(ch_null_preprocessed_keyed.map { _cohort_id, preprocessed_null -> preprocessed_null })
        .map { meta, checkpoint, config, preprocessed_null ->
            tuple(
                [id: meta.id, run_id: "explain_null_ablation_${meta.level}", stage: 'ablation_null', level: meta.level],
                checkpoint,
                config,
                preprocessed_null,
                true
            )
        }

    SIEVE_EXPLAIN_NULL_ABLATION(ch_null_ablation_explain_input)
    ch_versions = ch_versions.mix(SIEVE_EXPLAIN_NULL_ABLATION.out.versions)

    // -----------------------------------------------------------------------
    // Per-level attribution comparison: real vs null
    // -----------------------------------------------------------------------

    ch_ablation_real_variant_by_level = SIEVE_EXPLAIN_ABLATION.out.rankings.map { meta, variant_rankings, _gene, _interactions ->
        tuple(meta.level, meta, variant_rankings)
    }

    ch_ablation_null_variant_by_level = SIEVE_EXPLAIN_NULL_ABLATION.out.rankings.map { meta, variant_rankings, _gene, _interactions ->
        tuple(meta.level, variant_rankings)
    }

    ch_compare_abl_input = ch_ablation_real_variant_by_level
        .join(ch_ablation_null_variant_by_level, by: 0)
        .map { level, real_meta, real_variant_rankings, null_variant_rankings ->
            tuple(
                [id: real_meta.id, run_id: "compare_ablation_${level}", stage: 'ablation_null', level: level],
                real_variant_rankings,
                null_variant_rankings
            )
        }

    SIEVE_COMPARE_ATTRIBUTIONS_ABL(ch_compare_abl_input)
    ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_ABL.out.versions)

    // Per-level bootstrap calibration
    ch_ablation_null_npz_by_level = SIEVE_EXPLAIN_NULL_ABLATION.out.explain_dir.map { meta, explain_dir ->
        def npz = explain_dir.resolve('attributions.npz')
        tuple(meta.level, npz.exists() ? npz : [])
    }

    ch_bootstrap_abl_input = ch_ablation_real_variant_by_level
        .join(ch_ablation_null_npz_by_level, by: 0)
        .map { level, real_meta, real_variant_rankings, null_npz ->
            tuple(
                [id: real_meta.id, run_id: "bootstrap_ablation_${level}", stage: 'ablation_null', level: level],
                real_variant_rankings,
                null_npz
            )
        }
        .filter { _meta, _rankings, npz -> npz != [] }

    SIEVE_BOOTSTRAP_ABL(ch_bootstrap_abl_input)
    ch_versions = ch_versions.mix(SIEVE_BOOTSTRAP_ABL.out.versions)

    // Per-level chrX bias correction
    ch_chrx_abl_input = SIEVE_COMPARE_ATTRIBUTIONS_ABL.out.significance_rankings.map { meta, significance_csv ->
        tuple(
            [id: meta.id, run_id: "correct_chrx_ablation_${meta.level}", stage: 'ablation_null', level: meta.level],
            significance_csv
        )
    }

    SIEVE_CORRECT_CHRX_BIAS_ABL(ch_chrx_abl_input)
    ch_versions = ch_versions.mix(SIEVE_CORRECT_CHRX_BIAS_ABL.out.versions)

    ch_ablation_corrected_variant_by_level = SIEVE_CORRECT_CHRX_BIAS_ABL.out.corrected.map { meta, corrected_dir ->
        tuple(meta.level, meta, corrected_dir.resolve('corrected_variant_rankings.csv'))
    }

    // -----------------------------------------------------------------------
    // Gene list generation per level
    // -----------------------------------------------------------------------

    ch_ablation_calibrated_by_level = SIEVE_BOOTSTRAP_ABL.out.calibrated.map { meta, calibrated_rankings ->
        tuple(meta.level, calibrated_rankings)
    }

    ch_gene_list_input = ch_ablation_corrected_variant_by_level
        .join(ch_ablation_calibrated_by_level, by: 0)
        .map { level, real_meta, corrected_variant_rankings, calibrated_rankings ->
            tuple(
                [id: real_meta.id, run_id: "gene_list_${level}", stage: 'ablation', level: level],
                corrected_variant_rankings,
                calibrated_rankings
            )
        }

    SIEVE_GENERATE_GENE_LIST(ch_gene_list_input)
    ch_versions = ch_versions.mix(SIEVE_GENERATE_GENE_LIST.out.versions)

    // -----------------------------------------------------------------------
    // Ranking comparison across levels and ablation plot
    // -----------------------------------------------------------------------

    ch_all_ablation_ranking_files = ch_ablation_corrected_variant_by_level
        .map { level, _meta, corrected_variant_rankings ->
            ["${level}_sieve_variant_rankings.csv", corrected_variant_rankings]
        }
        .map { label, source_file ->
            [label, source_file]
        }
        .collectFile { label, source_file ->
            [label, source_file]
        }
        .collect()

    SIEVE_ABLATION_RANKING_COMPARE(
        ch_selection_meta,
        ch_all_ablation_ranking_files
    )
    ch_versions = ch_versions.mix(SIEVE_ABLATION_RANKING_COMPARE.out.versions)

    // Ablation comparison plot
    ch_plot_ablation_input = SIEVE_ABLATION_RANKING_COMPARE.out.ranking_comparison
        .combine(SIEVE_ABLATION_COMPARE.out.ablation_summary.map { _meta, _tsv, summary_yaml -> summary_yaml })
        .map { meta, jaccard_tsv, level_specific_tsv, summary_yaml ->
            tuple(meta, jaccard_tsv, level_specific_tsv, summary_yaml)
        }

    SIEVE_PLOT_ABLATION_COMPARISON(ch_plot_ablation_input)
    ch_versions = ch_versions.mix(SIEVE_PLOT_ABLATION_COMPARISON.out.versions)

    // -----------------------------------------------------------------------
    // Collect per-level outputs for publishing
    // -----------------------------------------------------------------------

    ch_ablation_training_per_level = SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload
    ch_ablation_attributions_per_level = SIEVE_EXPLAIN_ABLATION.out.explain_dir
    ch_null_training_per_level = SIEVE_TRAIN_SINGLE_NULL_ABLATION.out.selection_payload
    ch_null_attributions_per_level = SIEVE_EXPLAIN_NULL_ABLATION.out.explain_dir
    ch_attribution_comparison_per_level = SIEVE_COMPARE_ATTRIBUTIONS_ABL.out.comparison
    ch_attribution_comparison_corrected_per_level = SIEVE_CORRECT_CHRX_BIAS_ABL.out.corrected
    ch_bootstrap_calibration_per_level = SIEVE_BOOTSTRAP_ABL.out.calibrated
    ch_gene_list_delta_per_level = SIEVE_GENERATE_GENE_LIST.out.gene_list_delta
    ch_gene_list_zattr_per_level = SIEVE_GENERATE_GENE_LIST.out.gene_list_zattr
    ch_variant_significance_per_level = SIEVE_GENERATE_GENE_LIST.out.variant_rankings

    ch_published_ablation_comparison = SIEVE_ABLATION_COMPARE.out.ablation_summary
        .map { _meta, ablation_tsv, ablation_yaml ->
            [ablation_tsv, ablation_yaml]
        }
        .mix(
            SIEVE_ABLATION_RANKING_COMPARE.out.ranking_comparison.map { _meta, jaccard_tsv, level_specific_tsv ->
                [jaccard_tsv, level_specific_tsv]
            }
        )
        .mix(
            SIEVE_PLOT_ABLATION_COMPARISON.out.plot.map { _meta, plot_png -> plot_png }
        )

    emit:
    ablation_training_per_level                 = ch_ablation_training_per_level
    ablation_attributions_per_level             = ch_ablation_attributions_per_level
    null_training_per_level                     = ch_null_training_per_level
    null_attributions_per_level                 = ch_null_attributions_per_level
    attribution_comparison_per_level            = ch_attribution_comparison_per_level
    attribution_comparison_corrected_per_level  = ch_attribution_comparison_corrected_per_level
    bootstrap_calibration_per_level             = ch_bootstrap_calibration_per_level
    gene_list_delta_per_level                   = ch_gene_list_delta_per_level
    gene_list_zattr_per_level                   = ch_gene_list_zattr_per_level
    variant_significance_per_level              = ch_variant_significance_per_level
    published_ablation_comparison               = ch_published_ablation_comparison
    versions                                    = ch_versions
    plot_sources                                = ch_plot_sources
}
