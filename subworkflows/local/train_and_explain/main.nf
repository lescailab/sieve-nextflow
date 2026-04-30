//
// Subworkflow: Train CV, select best checkpoint, explain real data, null baseline comparison
//

include { SIEVE_TRAIN_CV                                                            } from '../../../modules/local/sieve/train_cv/main'
include { SIEVE_SELECT_BEST_CHECKPOINT                                              } from '../../../modules/local/sieve/select_best_checkpoint/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_REAL                                       } from '../../../modules/local/sieve/explain/main'
include { SIEVE_CREATE_NULL_BASELINE                                                } from '../../../modules/local/sieve/create_null_baseline/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_NULL                             } from '../../../modules/local/sieve/train_single/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_NULL                                       } from '../../../modules/local/sieve/explain/main'
include { SIEVE_COMPARE_ATTRIBUTIONS as SIEVE_COMPARE_ATTRIBUTIONS_RAW              } from '../../../modules/local/sieve/compare_attributions/main'
include { SIEVE_BOOTSTRAP_NULL_CALIBRATION                                          } from '../../../modules/local/sieve/bootstrap_null_calibration/main'
include { SIEVE_CORRECT_CHRX_BIAS                                                   } from '../../../modules/local/sieve/correct_chrx_bias/main'
include { resolveExecuteSteps } from '../../../lib/sieve_helpers'

workflow TRAIN_AND_EXPLAIN {

    take:
    _ch_selection_meta         // channel: val([id: cohort_id])
    ch_preprocessed_keyed      // channel: [ val(cohort_id), path(preprocessed) ]
    ch_sex_map_keyed           // channel: [ val(cohort_id), path(sex_map) ]
    ch_best_params_path_keyed  // channel: [ val(cohort_id), path(best_params) ]
    ch_best_params_map_keyed   // channel: [ val(cohort_id), val(params_map) ]

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']

    def selectedSteps = resolveExecuteSteps(params.execute_step)

    def targetCv = selectedSteps.contains('cv')
    def targetExplain = selectedSteps.contains('explain')
    def targetNull = selectedSteps.contains('null')
    def targetEpistasis = selectedSteps.contains('epistasis')
    def targetValidation = selectedSteps.contains('validation')

    def useProvidedBestCheckpoint = (params.best_checkpoint && params.checkpoint_config) as boolean

    def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull
    def needBestCheckpoint = targetCv || needExplain

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

    //
    // Best checkpoint: train CV + select, or use provided
    //
    ch_best_checkpoint_keyed = channel.empty()
    ch_published_best_model = channel.empty()
    ch_published_cv_folds = channel.empty()

    if (needBestCheckpoint) {
        if (useProvidedBestCheckpoint) {
            ch_best_checkpoint_keyed = channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.best_checkpoint, checkIfExists: true),
                    file(params.checkpoint_config, checkIfExists: true)
                )
            )

            ch_published_best_model = ch_best_checkpoint_keyed.map { _cohort_id, checkpoint, config ->
                [checkpoint, config]
            }
        } else {
            ch_cv_spec = channel.value(
                tuple(
                    cohortMeta.id,
                    [id: cohortMeta.id, run_id: 'cv_main', stage: 'cv', level: params.default_train_level],
                    params.default_train_level,
                    params.cv_folds
                )
            )

            ch_cv_input = ch_cv_spec
                .join(ch_preprocessed_keyed, by: 0)
                .join(ch_sex_map_keyed, by: 0)
                .join(ch_best_params_path_keyed, by: 0)
                .map { _key, meta, level, cv_folds, preprocessed, sex_map, best_params ->
                    tuple(meta, preprocessed, sex_map, best_params, level, cv_folds)
                }

            SIEVE_TRAIN_CV(ch_cv_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_CV.out.versions)
            ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_CV.out.cv_bundle.map { _meta, cv_output, _cv_results -> cv_output })

            SIEVE_SELECT_BEST_CHECKPOINT(SIEVE_TRAIN_CV.out.cv_bundle)
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_CHECKPOINT.out.versions)

            ch_best_checkpoint_keyed = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { meta, checkpoint, config, _fold_id, _summary ->
                tuple(meta.id, checkpoint, config)
            }

            ch_published_best_model = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { _meta, checkpoint, fold_config, _fold_id, cv_summary ->
                [checkpoint, fold_config, cv_summary]
            }

            ch_published_cv_folds = SIEVE_TRAIN_CV.out.cv_bundle.map { _meta, cv_output, _cv_results ->
                cv_output
            }
        }
    }

    //
    // Explain real data
    //
    ch_real_rankings = channel.empty()
    ch_real_variant_keyed = channel.empty()
    ch_real_gene_keyed = channel.empty()
    ch_published_explainability_best = channel.empty()

    if (needExplain) {
        ch_explain_real_input = ch_best_checkpoint_keyed
            .join(ch_preprocessed_keyed, by: 0)
            .map { key, checkpoint, config, preprocessed ->
                tuple([id: key, run_id: 'explain_real', stage: 'explain', level: params.default_train_level], checkpoint, config, preprocessed, false)
            }

        SIEVE_EXPLAIN_REAL(ch_explain_real_input)
        ch_versions = ch_versions.mix(SIEVE_EXPLAIN_REAL.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_REAL.out.explain_dir.map { _meta, explain_dir -> explain_dir })

        ch_real_rankings = SIEVE_EXPLAIN_REAL.out.rankings
        ch_real_variant_keyed = ch_real_rankings.map { meta, variant_rankings, _gene_rankings, _interactions ->
            tuple(meta.id, variant_rankings)
        }
        ch_real_gene_keyed = ch_real_rankings.map { meta, _variant_rankings, gene_rankings, _interactions ->
            tuple(meta.id, gene_rankings)
        }
        ch_published_explainability_best = SIEVE_EXPLAIN_REAL.out.explain_dir.map { _meta, explain_dir ->
            explain_dir
        }
    }

    //
    // Null baseline: create null data, train, explain, compare attributions, bootstrap calibration, chrX correction
    //
    ch_null_preprocessed_keyed = channel.empty()
    ch_published_null_model = channel.empty()
    ch_published_null_attributions = channel.empty()
    ch_published_null_comparison = channel.empty()
    ch_published_null_comparison_corrected = channel.empty()
    ch_published_bootstrap_calibration = channel.empty()
    ch_null_attributions_npz = channel.value([])
    ch_null_variant_rankings = channel.value([])

    if (targetNull) {
        ch_null_baseline_input = ch_preprocessed_keyed.map { cohort_id, preprocessed ->
            tuple([id: cohort_id, run_id: 'null_baseline_dataset', stage: 'null_baseline'], preprocessed, params.null_seed)
        }

        SIEVE_CREATE_NULL_BASELINE(ch_null_baseline_input)
        ch_versions = ch_versions.mix(SIEVE_CREATE_NULL_BASELINE.out.versions)

        ch_null_preprocessed_keyed = SIEVE_CREATE_NULL_BASELINE.out.null_preprocessed.map { meta, preprocessed_null ->
            tuple(meta.id, preprocessed_null)
        }

        ch_null_train_spec = channel.value(
            tuple(
                cohortMeta.id,
                [id: cohortMeta.id, run_id: 'null_train', stage: 'null_baseline', level: params.default_train_level],
                params.default_train_level,
                params.val_split
            )
        )

        ch_null_train_input = ch_null_train_spec
            .join(ch_null_preprocessed_keyed, by: 0)
            .join(ch_sex_map_keyed, by: 0)
            .join(ch_best_params_map_keyed, by: 0)
            .map { _key, meta, level, val_split, preprocessed_null, sex_map, best_params_map ->
                def nullParams = new LinkedHashMap(baseTrainingParams)
                nullParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
                nullParams.put('annotation_level', level)
                tuple(meta, preprocessed_null, sex_map, nullParams, level, val_split)
            }

        SIEVE_TRAIN_SINGLE_NULL(ch_null_train_input)
        ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_NULL.out.versions)

        ch_null_model_keyed = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts.map { meta, _results, config, model ->
            tuple(meta.id, model, config)
        }

        ch_null_explain_input = ch_null_model_keyed
            .join(ch_null_preprocessed_keyed, by: 0)
            .map { key, checkpoint, config, preprocessed_null ->
                tuple([id: key, run_id: 'explain_null', stage: 'null_baseline', level: params.default_train_level], checkpoint, config, preprocessed_null, true)
            }

        SIEVE_EXPLAIN_NULL(ch_null_explain_input)
        ch_versions = ch_versions.mix(SIEVE_EXPLAIN_NULL.out.versions)

        ch_null_variant_keyed = SIEVE_EXPLAIN_NULL.out.rankings.map { meta, variant_rankings, _gene_rankings, _interactions ->
            tuple(meta.id, variant_rankings)
        }

        // Compare real vs null attributions
        ch_compare_attributions_input = ch_real_variant_keyed
            .join(ch_null_variant_keyed, by: 0)
            .map { key, real_variant_rankings, null_variant_rankings ->
                tuple([id: key, run_id: 'compare_attributions', stage: 'null_baseline', level: params.default_train_level], real_variant_rankings, null_variant_rankings)
            }

        SIEVE_COMPARE_ATTRIBUTIONS_RAW(ch_compare_attributions_input)
        ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { _meta, _summary, comparison_dir -> comparison_dir })

        // Bootstrap null calibration
        ch_null_npz_for_bootstrap = SIEVE_EXPLAIN_NULL.out.explain_dir.map { meta, explain_dir ->
            def npz = explain_dir.resolve('attributions.npz')
            tuple(meta.id, npz.exists() ? npz : [])
        }

        ch_bootstrap_input = ch_real_variant_keyed
            .join(ch_null_npz_for_bootstrap, by: 0)
            .map { key, real_variant_rankings, null_npz ->
                tuple([id: key, run_id: 'bootstrap_calibration', stage: 'null_baseline', level: params.default_train_level], real_variant_rankings, null_npz)
            }
            .filter { _meta, _rankings, npz -> npz != [] }

        SIEVE_BOOTSTRAP_NULL_CALIBRATION(ch_bootstrap_input)
        ch_versions = ch_versions.mix(SIEVE_BOOTSTRAP_NULL_CALIBRATION.out.versions)

        // ChrX bias correction applied to significance rankings from raw comparison
        ch_chrx_input = SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.significance_rankings.map { meta, significance_csv ->
            tuple([id: meta.id, run_id: 'correct_chrx', stage: 'null_baseline', level: params.default_train_level], significance_csv)
        }

        SIEVE_CORRECT_CHRX_BIAS(ch_chrx_input)
        ch_versions = ch_versions.mix(SIEVE_CORRECT_CHRX_BIAS.out.versions)

        ch_published_null_model = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts
            .map { _meta, null_results, null_config, null_model ->
                [null_model, null_config, null_results]
            }
            .mix(
                SIEVE_TRAIN_SINGLE_NULL.out.history.map { _meta, null_history ->
                    null_history
                }
            )
            .mix(
                SIEVE_CREATE_NULL_BASELINE.out.null_preprocessed.map { _meta, null_preprocessed ->
                    null_preprocessed
                }
            )

        ch_published_null_attributions = SIEVE_EXPLAIN_NULL.out.explain_dir.map { _meta, null_explain_dir ->
            null_explain_dir
        }

        ch_published_null_comparison = SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { _meta, comparison_summary, comparison_dir ->
            [comparison_summary, comparison_dir]
        }

        ch_published_null_comparison_corrected = SIEVE_CORRECT_CHRX_BIAS.out.corrected.map { _meta, corrected_dir ->
            corrected_dir
        }

        ch_published_bootstrap_calibration = SIEVE_BOOTSTRAP_NULL_CALIBRATION.out.calibrated.map { _meta, calibrated_csv ->
            calibrated_csv
        }

        // Channels for downstream subworkflows
        ch_null_attributions_npz = SIEVE_EXPLAIN_NULL.out.explain_dir.map { _meta, explain_dir ->
            def npz = explain_dir.resolve('attributions.npz')
            npz.exists() ? npz : []
        }

        ch_null_variant_rankings = SIEVE_EXPLAIN_NULL.out.rankings.map { _meta, variant_rankings, _gene_rankings, _interactions -> variant_rankings }
    }

    emit:
    best_checkpoint_keyed              = ch_best_checkpoint_keyed              // channel: [ val(cohort_id), path(checkpoint), path(config) ]
    real_rankings                      = ch_real_rankings                      // channel: [ val(meta), path(variant), path(gene), path(interactions) ]
    null_preprocessed_keyed            = ch_null_preprocessed_keyed            // channel: [ val(cohort_id), path(preprocessed_null) ]
    published_best_model               = ch_published_best_model               // channel: publish files
    published_cv_folds                 = ch_published_cv_folds                 // channel: path(cv_output dir)
    published_explainability_best      = ch_published_explainability_best      // channel: path(explain_dir)
    published_null_model               = ch_published_null_model               // channel: publish files
    published_null_attributions        = ch_published_null_attributions        // channel: path(null_explain_dir)
    published_null_comparison          = ch_published_null_comparison          // channel: publish files
    published_null_comparison_corrected = ch_published_null_comparison_corrected // channel: path(corrected dir)
    published_bootstrap_calibration    = ch_published_bootstrap_calibration    // channel: path(calibrated csv)
    null_attributions_npz              = ch_null_attributions_npz              // channel: path(npz) or val([])
    null_variant_rankings              = ch_null_variant_rankings              // channel: path(rankings) or val([])
    versions                           = ch_versions                           // channel: path(versions.yml)
    plot_sources                       = ch_plot_sources                        // channel: path(plot_files)
}
