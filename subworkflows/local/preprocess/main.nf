//
// Subworkflow: Prepare all necessary files — sex map, preprocessed data, best params, reference databases
//

include { SIEVE_INFER_SEX                                   } from '../../../modules/local/sieve/infer_sex/main'
include { SIEVE_EMIT_SEX_MAP                                } from '../../../modules/local/sieve/emit_sex_map/main'
include { SIEVE_PREPROCESS                                  } from '../../../modules/local/sieve/preprocess/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_GRID     } from '../../../modules/local/sieve/train_single/main'
include { SIEVE_SELECT_BEST_PARAMS                          } from '../../../modules/local/sieve/select_best_params/main'
include { SIEVE_DOWNLOAD_REFERENCES                         } from '../../../modules/local/sieve/download_references/main'
include { buildTrainingGrid; extractTrainingParams; resolveExecuteSteps } from '../../../lib/sieve_helpers'

workflow PREPROCESS {

    take:
    ch_selection_meta    // channel: val([id: cohort_id])

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']

    def selectedSteps = resolveExecuteSteps(params.execute_step)

    def targetSex = selectedSteps.contains('sex')
    def targetPreprocess = selectedSteps.contains('preprocess')
    def targetGrid = selectedSteps.contains('grid')
    def targetCv = selectedSteps.contains('cv')
    def targetExplain = selectedSteps.contains('explain')
    def targetAblation = selectedSteps.contains('ablation')
    def targetNull = selectedSteps.contains('null')
    def targetEpistasis = selectedSteps.contains('epistasis')
    def targetValidation = selectedSteps.contains('validation')

    def useProvidedSexMap = params.sex_map as boolean
    def useProvidedPreprocessed = params.preprocessed_data as boolean
    def useProvidedBestParams = params.best_params as boolean
    def useProvidedBestCheckpoint = (params.best_checkpoint && params.checkpoint_config) as boolean

    def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull || targetAblation
    def needBestCheckpoint = targetCv || needExplain
    def needBestParams = targetGrid || targetAblation || targetNull || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needPreprocessed = targetPreprocess || needBestParams || needExplain || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needSexMap = targetSex || needBestParams || (needPreprocessed && !useProvidedPreprocessed)

    //
    // Sex map: infer or use provided
    //
    ch_effective_sex_map = channel.empty()

    if (needSexMap) {
        ch_resolved_sex_map = channel.empty()

        if (useProvidedSexMap) {
            ch_resolved_sex_map = channel.value(
                tuple(
                    cohortMeta,
                    file(params.sex_map, checkIfExists: true)
                )
            )
        } else {
            if (!params.infer_sex) {
                error('The selected steps require a sex map. Provide --sex_map or set --infer_sex true.')
            }

            ch_vcf_for_sex = channel
                .fromPath(params.vcf, checkIfExists: true)
                .map { vcf ->
                    def idx = file("${vcf}.tbi").exists() ? file("${vcf}.tbi") :
                              file("${vcf}.csi").exists() ? file("${vcf}.csi") :
                              []
                    tuple(cohortMeta, vcf, idx)
                }

            SIEVE_INFER_SEX(
                ch_vcf_for_sex,
                params.genome_build
            )
            ch_resolved_sex_map = SIEVE_INFER_SEX.out.sex_map
            ch_versions = ch_versions.mix(SIEVE_INFER_SEX.out.versions)
            ch_plot_sources = ch_plot_sources.mix(SIEVE_INFER_SEX.out.diagnostics.map { _meta, diagnostic -> diagnostic })
        }

        SIEVE_EMIT_SEX_MAP(ch_resolved_sex_map)
        ch_effective_sex_map = SIEVE_EMIT_SEX_MAP.out.sex_map
        ch_versions = ch_versions.mix(SIEVE_EMIT_SEX_MAP.out.versions)
    }

    //
    // Preprocess: run or use provided
    //
    ch_preprocessed = channel.empty()

    if (needPreprocessed) {
        if (useProvidedPreprocessed) {
            ch_preprocessed = channel.value(
                tuple(
                    cohortMeta,
                    file(params.preprocessed_data, checkIfExists: true)
                )
            )
        } else {
            ch_vcf_for_preprocess = channel
                .fromPath(params.vcf, checkIfExists: true)
                .map { vcf -> tuple(cohortMeta, vcf) }

            ch_phenotypes = channel
                .fromPath(params.phenotypes, checkIfExists: true)
                .map { phenotypes -> tuple(cohortMeta, phenotypes) }

            ch_preprocess_input = ch_vcf_for_preprocess
                .combine(ch_phenotypes, by: 0)
                .combine(ch_effective_sex_map, by: 0)
                .map { meta, vcf, phenotypes, sex_map ->
                    tuple(meta, vcf, phenotypes, sex_map)
                }

            SIEVE_PREPROCESS(
                ch_preprocess_input,
                params.genome_build
            )
            ch_versions = ch_versions.mix(SIEVE_PREPROCESS.out.versions)
            ch_preprocessed = SIEVE_PREPROCESS.out.preprocessed
        }
    }

    ch_preprocessed_keyed = ch_preprocessed.map { meta, preprocessed ->
        tuple(meta.id, preprocessed)
    }

    ch_sex_map_keyed = ch_effective_sex_map.map { meta, sex_map ->
        tuple(meta.id, sex_map)
    }

    //
    // Grid search + select best params
    //
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

    ch_best_params_path_keyed = channel.empty()
    ch_best_params_map_keyed = channel.empty()

    if (needBestParams) {
        if (useProvidedBestParams) {
            ch_best_params_path_keyed = channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.best_params, checkIfExists: true)
                )
            )
        } else if (useProvidedBestCheckpoint) {
            ch_best_params_path_keyed = channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.checkpoint_config, checkIfExists: true)
                )
            )
        } else {
            def trainingGrid = buildTrainingGrid(
                baseTrainingParams,
                params.grid_lr,
                params.grid_lambda_attr,
                params.grid_latent_dim,
                params.grid_hidden_dim,
                params.grid_num_attention_layers
            )

            ch_grid_specs = channel
                .fromList(trainingGrid)
                .map { grid_params ->
                    tuple(
                        cohortMeta.id,
                        [id: cohortMeta.id, run_id: grid_params.run_id, stage: 'grid', level: params.default_train_level],
                        grid_params,
                        params.default_train_level,
                        params.val_split
                    )
                }

            ch_grid_train_input = ch_grid_specs
                .combine(ch_preprocessed_keyed, by: 0)
                .combine(ch_sex_map_keyed, by: 0)
                .map { _key, meta, grid_params, level, val_split, preprocessed, sex_map ->
                    tuple(meta, preprocessed, sex_map, grid_params, level, val_split)
                }

            SIEVE_TRAIN_SINGLE_GRID(ch_grid_train_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_GRID.out.versions)

            ch_grid_selection_dirs = SIEVE_TRAIN_SINGLE_GRID.out.selection_payload
                .map { _meta, run_dir -> run_dir }
                .collect()

            SIEVE_SELECT_BEST_PARAMS(
                ch_selection_meta,
                ch_grid_selection_dirs
            )
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_PARAMS.out.versions)

            ch_best_params_path_keyed = SIEVE_SELECT_BEST_PARAMS.out.best_params.map { meta, best_params, _best_run_id, _summary ->
                tuple(meta.id, best_params)
            }
        }

        ch_best_params_map_keyed = ch_best_params_path_keyed.map { cohort_id, best_params_path ->
            tuple(cohort_id, extractTrainingParams(best_params_path))
        }
    }

    //
    // Download reference databases (for validation)
    //
    ch_ref_clinvar = channel.empty()
    ch_ref_gwas = channel.empty()
    ch_ref_go_mapping = channel.empty()

    if (targetValidation) {
        def hasProvidedRefs = params.clinvar_tsv || params.gwas_tsv || params.go_mapping_json

        if (hasProvidedRefs) {
            ch_ref_clinvar     = params.clinvar_tsv     ? channel.value(file(params.clinvar_tsv, checkIfExists: true))     : channel.value(file('NO_FILE'))
            ch_ref_gwas        = params.gwas_tsv        ? channel.value(file(params.gwas_tsv, checkIfExists: true))        : channel.value(file('NO_FILE2'))
            ch_ref_go_mapping  = params.go_mapping_json ? channel.value(file(params.go_mapping_json, checkIfExists: true)) : channel.value(file('NO_FILE3'))
        } else {
            SIEVE_DOWNLOAD_REFERENCES(
                ch_selection_meta,
                params.genome_build
            )
            ch_versions = ch_versions.mix(SIEVE_DOWNLOAD_REFERENCES.out.versions)

            ch_ref_clinvar    = SIEVE_DOWNLOAD_REFERENCES.out.references.map { _meta, clinvar, _gwas, _go -> clinvar }
            ch_ref_gwas       = SIEVE_DOWNLOAD_REFERENCES.out.references.map { _meta, _clinvar, gwas, _go -> gwas }
            ch_ref_go_mapping = SIEVE_DOWNLOAD_REFERENCES.out.references.map { _meta, _clinvar, _gwas, go -> go }
        }
    }

    emit:
    sex_map                = ch_effective_sex_map           // channel: [ val(meta), path(sex_map) ]
    preprocessed           = ch_preprocessed                // channel: [ val(meta), path(preprocessed) ]
    preprocessed_keyed     = ch_preprocessed_keyed          // channel: [ val(cohort_id), path(preprocessed) ]
    sex_map_keyed          = ch_sex_map_keyed               // channel: [ val(cohort_id), path(sex_map) ]
    best_params_path_keyed = ch_best_params_path_keyed      // channel: [ val(cohort_id), path(best_params) ]
    best_params_map_keyed  = ch_best_params_map_keyed       // channel: [ val(cohort_id), val(params_map) ]
    ref_clinvar            = ch_ref_clinvar                  // channel: path(clinvar)
    ref_gwas               = ch_ref_gwas                     // channel: path(gwas)
    ref_go_mapping         = ch_ref_go_mapping               // channel: path(go_mapping)
    versions               = ch_versions                     // channel: path(versions.yml)
    plot_sources           = ch_plot_sources                  // channel: path(plot_files)
}
