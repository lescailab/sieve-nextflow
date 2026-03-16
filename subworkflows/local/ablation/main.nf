//
// Subworkflow: Ablation analysis — train per-level models, explain, and compare rankings
//

include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_ABLATION } from '../../../modules/local/sieve/train_single/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_ABLATION            } from '../../../modules/local/sieve/explain/main'
include { SIEVE_ABLATION_COMPARE                             } from '../../../modules/local/sieve/ablation_compare/main'
include { SIEVE_ABLATION_RANKING_COMPARE                     } from '../../../modules/local/sieve/ablation_ranking_compare/main'

workflow ABLATION {

    take:
    ch_selection_meta          // channel: val([id: cohort_id])
    ch_preprocessed_keyed      // channel: [ val(cohort_id), path(preprocessed) ]
    ch_sex_map_keyed           // channel: [ val(cohort_id), path(sex_map) ]
    ch_best_params_map_keyed   // channel: [ val(cohort_id), val(params_map) ]
    ch_real_rankings           // channel: [ val(meta), path(variant), path(gene), path(interactions) ]

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']

    def baseTrainingParams = [
        epochs: params.train_epochs as Integer,
        batch_size: params.train_batch_size as Integer,
        chunk_size: params.train_chunk_size as Integer,
        aggregation_method: params.train_aggregation_method,
        gradient_accumulation_steps: params.train_gradient_accumulation_steps as Integer,
        gradient_clip: params.train_gradient_clip as Double,
        seed: params.train_seed as Integer,
        device: params.train_device,
        early_stopping: params.train_early_stopping as Integer,
        hidden_dim: params.train_hidden_dim as Integer,
        num_attention_layers: params.train_num_attention_layers as Integer,
    ].findAll { _key, value -> value != null }

    // Train only L0-L2 from scratch; L3 reuses the best checkpoint via explain
    ch_ablation_specs = channel
        .fromList(['L0', 'L1', 'L2'])
        .map { level ->
            tuple(
                cohortMeta.id,
                [id: cohortMeta.id, run_id: "ablation_${level}", stage: 'ablation', level: level],
                level,
                params.val_split
            )
        }

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

    // Metrics comparison: collect L0-L2 selection payloads for ABLATION_COMPARE
    ch_ablation_selection_dirs = SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload
        .map { _meta, run_dir -> run_dir }
        .collect()

    SIEVE_ABLATION_COMPARE(
        ch_selection_meta,
        ch_ablation_selection_dirs
    )
    ch_versions = ch_versions.mix(SIEVE_ABLATION_COMPARE.out.versions)

    // Run explainability on each ablation model (L0-L2)
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

    // Collect L0-L2 rankings and rename with level prefix
    ch_ablation_L0L2_rankings = SIEVE_EXPLAIN_ABLATION.out.rankings
        .map { meta, variant_rankings, gene_rankings, _interactions ->
            tuple(meta.level, variant_rankings, gene_rankings)
        }

    // L3 rankings come from the explain_real output on the best checkpoint
    ch_ablation_L3_rankings = ch_real_rankings
        .map { _meta, variant_rankings, gene_rankings, _interactions ->
            tuple('L3', variant_rankings, gene_rankings)
        }

    // Merge all levels and collect ranking files with level prefixes
    ch_all_ablation_ranking_files = ch_ablation_L0L2_rankings
        .mix(ch_ablation_L3_rankings)
        .flatMap { level, variant_rankings, gene_rankings ->
            [[level, 'variant', variant_rankings], [level, 'gene', gene_rankings]]
        }
        .map { level, kind, rankings_file ->
            ["${level}_sieve_${kind}_rankings.csv", rankings_file]
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

    // Publish: metrics summary + ranking comparison + per-level explain outputs
    ch_published_ablation_discovery = SIEVE_ABLATION_COMPARE.out.ablation_summary
        .map { _meta, ablation_tsv, ablation_yaml ->
            [ablation_tsv, ablation_yaml]
        }
        .mix(
            SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { _meta, run_dir ->
                run_dir
            }
        )
        .mix(
            SIEVE_ABLATION_RANKING_COMPARE.out.ranking_comparison.map { _meta, comparison_yaml, jaccard_tsv, level_specific_tsv ->
                [comparison_yaml, jaccard_tsv, level_specific_tsv]
            }
        )
        .mix(
            SIEVE_EXPLAIN_ABLATION.out.explain_dir.map { _meta, explain_dir ->
                explain_dir
            }
        )

    emit:
    published_ablation_discovery = ch_published_ablation_discovery  // channel: publish files
    versions                     = ch_versions                      // channel: path(versions.yml)
    plot_sources                 = ch_plot_sources                   // channel: path(plot_files)
}
