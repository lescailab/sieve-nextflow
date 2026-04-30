#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    lescailab/sieve
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/lescailab/sieve-nextflow
    Website: https://nf-co.re/sieve
    Slack  : https://nfcore.slack.com/channels/sieve
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SIEVE } from './workflows/sieve'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_sieve_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_sieve_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NFCORE_SIEVE {

    main:

    SIEVE()

    emit:
    sex_map                          = SIEVE.out.sex_map
    preprocessed_dataset             = SIEVE.out.preprocessed_dataset
    real_training                    = SIEVE.out.real_training
    real_cv_folds                    = SIEVE.out.real_cv_folds
    real_attributions                = SIEVE.out.real_attributions
    null_training_l3                 = SIEVE.out.null_training_l3
    null_attributions_l3             = SIEVE.out.null_attributions_l3
    null_comparison_l3               = SIEVE.out.null_comparison_l3
    null_comparison_corrected_l3     = SIEVE.out.null_comparison_corrected_l3
    bootstrap_calibration_l3         = SIEVE.out.bootstrap_calibration_l3
    ablation_training_l0             = SIEVE.out.ablation_training_l0
    ablation_training_l1             = SIEVE.out.ablation_training_l1
    ablation_training_l2             = SIEVE.out.ablation_training_l2
    ablation_training_l3             = SIEVE.out.ablation_training_l3
    ablation_attributions_l0         = SIEVE.out.ablation_attributions_l0
    ablation_attributions_l1         = SIEVE.out.ablation_attributions_l1
    ablation_attributions_l2         = SIEVE.out.ablation_attributions_l2
    ablation_attributions_l3         = SIEVE.out.ablation_attributions_l3
    ablation_null_training_l0        = SIEVE.out.ablation_null_training_l0
    ablation_null_training_l1        = SIEVE.out.ablation_null_training_l1
    ablation_null_training_l2        = SIEVE.out.ablation_null_training_l2
    ablation_null_training_l3        = SIEVE.out.ablation_null_training_l3
    ablation_null_attributions_l0    = SIEVE.out.ablation_null_attributions_l0
    ablation_null_attributions_l1    = SIEVE.out.ablation_null_attributions_l1
    ablation_null_attributions_l2    = SIEVE.out.ablation_null_attributions_l2
    ablation_null_attributions_l3    = SIEVE.out.ablation_null_attributions_l3
    ablation_comparison_l0           = SIEVE.out.ablation_comparison_l0
    ablation_comparison_l1           = SIEVE.out.ablation_comparison_l1
    ablation_comparison_l2           = SIEVE.out.ablation_comparison_l2
    ablation_comparison_l3           = SIEVE.out.ablation_comparison_l3
    ablation_comparison_corrected_l0 = SIEVE.out.ablation_comparison_corrected_l0
    ablation_comparison_corrected_l1 = SIEVE.out.ablation_comparison_corrected_l1
    ablation_comparison_corrected_l2 = SIEVE.out.ablation_comparison_corrected_l2
    ablation_comparison_corrected_l3 = SIEVE.out.ablation_comparison_corrected_l3
    ablation_bootstrap_l0            = SIEVE.out.ablation_bootstrap_l0
    ablation_bootstrap_l1            = SIEVE.out.ablation_bootstrap_l1
    ablation_bootstrap_l2            = SIEVE.out.ablation_bootstrap_l2
    ablation_bootstrap_l3            = SIEVE.out.ablation_bootstrap_l3
    ablation_gene_delta_l0           = SIEVE.out.ablation_gene_delta_l0
    ablation_gene_delta_l1           = SIEVE.out.ablation_gene_delta_l1
    ablation_gene_delta_l2           = SIEVE.out.ablation_gene_delta_l2
    ablation_gene_delta_l3           = SIEVE.out.ablation_gene_delta_l3
    ablation_gene_zattr_l0           = SIEVE.out.ablation_gene_zattr_l0
    ablation_gene_zattr_l1           = SIEVE.out.ablation_gene_zattr_l1
    ablation_gene_zattr_l2           = SIEVE.out.ablation_gene_zattr_l2
    ablation_gene_zattr_l3           = SIEVE.out.ablation_gene_zattr_l3
    ablation_variant_significance_l0 = SIEVE.out.ablation_variant_significance_l0
    ablation_variant_significance_l1 = SIEVE.out.ablation_variant_significance_l1
    ablation_variant_significance_l2 = SIEVE.out.ablation_variant_significance_l2
    ablation_variant_significance_l3 = SIEVE.out.ablation_variant_significance_l3
    ablation_comparison_summary      = SIEVE.out.ablation_comparison_summary
    epistasis_audit                  = SIEVE.out.epistasis_audit
    gene_interactions                = SIEVE.out.gene_interactions
    validation                       = SIEVE.out.validation
    pipeline_versions                = SIEVE.out.pipeline_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // Extract positional arguments from command line for nf-core template checks
    // In strict syntax mode, we parse workflow.commandLine to detect accidental positional args
    //
    def cmdLine = workflow.commandLine.toString()
    def tokens = cmdLine.tokenize(' ')
    def runIdx = tokens.indexOf('run')
    // Filter tokens: skip 'nextflow', 'run', the script name, flags/options, assignments,
    // and values that immediately follow a flag (option arguments).
    def optionValuePositions = [] as Set
    tokens.eachWithIndex { token, idx ->
        if (idx > runIdx + 1 && token.startsWith('-') && !token.contains('=')) {
            if (idx + 1 < tokens.size() && !tokens[idx + 1].startsWith('-')) {
                optionValuePositions << (idx + 1)
            }
        }
    }
    def cli_args = tokens.indexed().findAll { idx, token ->
        idx > runIdx + 1 && !token.startsWith('-') && !token.contains('=') && !(idx in optionValuePositions)
    }.collect { _idx, token -> token }

    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        cli_args,
        params.outdir,
        params.vcf,
        params.phenotypes,
        params.genome_build,
        params.infer_sex,
        params.known_sex,
        params.sex_map,
        params.preprocessed_data,
        params.best_params,
        params.best_checkpoint,
        params.checkpoint_config,
        params.execute_step,
        params.help,
        params.help_full,
        params.show_hidden
    )

    NFCORE_SIEVE()

    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
    )

    publish:
    sex_map                          = NFCORE_SIEVE.out.sex_map
    preprocessed_dataset             = NFCORE_SIEVE.out.preprocessed_dataset
    real_training                    = NFCORE_SIEVE.out.real_training
    real_cv_folds                    = NFCORE_SIEVE.out.real_cv_folds
    real_attributions                = NFCORE_SIEVE.out.real_attributions
    null_training_l3                 = NFCORE_SIEVE.out.null_training_l3
    null_attributions_l3             = NFCORE_SIEVE.out.null_attributions_l3
    null_comparison_l3               = NFCORE_SIEVE.out.null_comparison_l3
    null_comparison_corrected_l3     = NFCORE_SIEVE.out.null_comparison_corrected_l3
    bootstrap_calibration_l3         = NFCORE_SIEVE.out.bootstrap_calibration_l3
    ablation_training_l0             = NFCORE_SIEVE.out.ablation_training_l0
    ablation_training_l1             = NFCORE_SIEVE.out.ablation_training_l1
    ablation_training_l2             = NFCORE_SIEVE.out.ablation_training_l2
    ablation_training_l3             = NFCORE_SIEVE.out.ablation_training_l3
    ablation_attributions_l0         = NFCORE_SIEVE.out.ablation_attributions_l0
    ablation_attributions_l1         = NFCORE_SIEVE.out.ablation_attributions_l1
    ablation_attributions_l2         = NFCORE_SIEVE.out.ablation_attributions_l2
    ablation_attributions_l3         = NFCORE_SIEVE.out.ablation_attributions_l3
    ablation_null_training_l0        = NFCORE_SIEVE.out.ablation_null_training_l0
    ablation_null_training_l1        = NFCORE_SIEVE.out.ablation_null_training_l1
    ablation_null_training_l2        = NFCORE_SIEVE.out.ablation_null_training_l2
    ablation_null_training_l3        = NFCORE_SIEVE.out.ablation_null_training_l3
    ablation_null_attributions_l0    = NFCORE_SIEVE.out.ablation_null_attributions_l0
    ablation_null_attributions_l1    = NFCORE_SIEVE.out.ablation_null_attributions_l1
    ablation_null_attributions_l2    = NFCORE_SIEVE.out.ablation_null_attributions_l2
    ablation_null_attributions_l3    = NFCORE_SIEVE.out.ablation_null_attributions_l3
    ablation_comparison_l0           = NFCORE_SIEVE.out.ablation_comparison_l0
    ablation_comparison_l1           = NFCORE_SIEVE.out.ablation_comparison_l1
    ablation_comparison_l2           = NFCORE_SIEVE.out.ablation_comparison_l2
    ablation_comparison_l3           = NFCORE_SIEVE.out.ablation_comparison_l3
    ablation_comparison_corrected_l0 = NFCORE_SIEVE.out.ablation_comparison_corrected_l0
    ablation_comparison_corrected_l1 = NFCORE_SIEVE.out.ablation_comparison_corrected_l1
    ablation_comparison_corrected_l2 = NFCORE_SIEVE.out.ablation_comparison_corrected_l2
    ablation_comparison_corrected_l3 = NFCORE_SIEVE.out.ablation_comparison_corrected_l3
    ablation_bootstrap_l0            = NFCORE_SIEVE.out.ablation_bootstrap_l0
    ablation_bootstrap_l1            = NFCORE_SIEVE.out.ablation_bootstrap_l1
    ablation_bootstrap_l2            = NFCORE_SIEVE.out.ablation_bootstrap_l2
    ablation_bootstrap_l3            = NFCORE_SIEVE.out.ablation_bootstrap_l3
    ablation_gene_delta_l0           = NFCORE_SIEVE.out.ablation_gene_delta_l0
    ablation_gene_delta_l1           = NFCORE_SIEVE.out.ablation_gene_delta_l1
    ablation_gene_delta_l2           = NFCORE_SIEVE.out.ablation_gene_delta_l2
    ablation_gene_delta_l3           = NFCORE_SIEVE.out.ablation_gene_delta_l3
    ablation_gene_zattr_l0           = NFCORE_SIEVE.out.ablation_gene_zattr_l0
    ablation_gene_zattr_l1           = NFCORE_SIEVE.out.ablation_gene_zattr_l1
    ablation_gene_zattr_l2           = NFCORE_SIEVE.out.ablation_gene_zattr_l2
    ablation_gene_zattr_l3           = NFCORE_SIEVE.out.ablation_gene_zattr_l3
    ablation_variant_significance_l0 = NFCORE_SIEVE.out.ablation_variant_significance_l0
    ablation_variant_significance_l1 = NFCORE_SIEVE.out.ablation_variant_significance_l1
    ablation_variant_significance_l2 = NFCORE_SIEVE.out.ablation_variant_significance_l2
    ablation_variant_significance_l3 = NFCORE_SIEVE.out.ablation_variant_significance_l3
    ablation_comparison_summary      = NFCORE_SIEVE.out.ablation_comparison_summary
    epistasis_audit                  = NFCORE_SIEVE.out.epistasis_audit
    gene_interactions                = NFCORE_SIEVE.out.gene_interactions
    validation                       = NFCORE_SIEVE.out.validation
    pipeline_versions                = NFCORE_SIEVE.out.pipeline_versions
}

output {
    sex_map                          { path "${params.cohort_id}/data" }
    preprocessed_dataset             { path "${params.cohort_id}/data" }

    real_training                    { path "${params.cohort_id}/real_experiments/L3/training" }
    real_cv_folds                    { path "${params.cohort_id}/real_experiments/L3/cross_fold" }
    real_attributions                { path "${params.cohort_id}/real_experiments/L3/attributions" }

    null_training_l3                 { path "${params.cohort_id}/null_baselines/L3/training" }
    null_attributions_l3             { path "${params.cohort_id}/null_baselines/L3/attributions" }
    null_comparison_l3               { path "${params.cohort_id}/attribution_comparison/L3" }
    null_comparison_corrected_l3     { path "${params.cohort_id}/attribution_comparison/L3" }
    bootstrap_calibration_l3         { path "${params.cohort_id}/attribution_comparison/L3" }

    ablation_training_l0             { path "${params.cohort_id}/real_experiments/L0/training" }
    ablation_training_l1             { path "${params.cohort_id}/real_experiments/L1/training" }
    ablation_training_l2             { path "${params.cohort_id}/real_experiments/L2/training" }
    ablation_training_l3             { path "${params.cohort_id}/real_experiments/L3/training" }
    ablation_attributions_l0         { path "${params.cohort_id}/real_experiments/L0/attributions" }
    ablation_attributions_l1         { path "${params.cohort_id}/real_experiments/L1/attributions" }
    ablation_attributions_l2         { path "${params.cohort_id}/real_experiments/L2/attributions" }
    ablation_attributions_l3         { path "${params.cohort_id}/real_experiments/L3/attributions" }

    ablation_null_training_l0        { path "${params.cohort_id}/null_baselines/L0/training" }
    ablation_null_training_l1        { path "${params.cohort_id}/null_baselines/L1/training" }
    ablation_null_training_l2        { path "${params.cohort_id}/null_baselines/L2/training" }
    ablation_null_training_l3        { path "${params.cohort_id}/null_baselines/L3/training" }
    ablation_null_attributions_l0    { path "${params.cohort_id}/null_baselines/L0/attributions" }
    ablation_null_attributions_l1    { path "${params.cohort_id}/null_baselines/L1/attributions" }
    ablation_null_attributions_l2    { path "${params.cohort_id}/null_baselines/L2/attributions" }
    ablation_null_attributions_l3    { path "${params.cohort_id}/null_baselines/L3/attributions" }

    ablation_comparison_l0           { path "${params.cohort_id}/attribution_comparison/L0" }
    ablation_comparison_l1           { path "${params.cohort_id}/attribution_comparison/L1" }
    ablation_comparison_l2           { path "${params.cohort_id}/attribution_comparison/L2" }
    ablation_comparison_l3           { path "${params.cohort_id}/attribution_comparison/L3" }
    ablation_comparison_corrected_l0 { path "${params.cohort_id}/attribution_comparison/L0" }
    ablation_comparison_corrected_l1 { path "${params.cohort_id}/attribution_comparison/L1" }
    ablation_comparison_corrected_l2 { path "${params.cohort_id}/attribution_comparison/L2" }
    ablation_comparison_corrected_l3 { path "${params.cohort_id}/attribution_comparison/L3" }
    ablation_bootstrap_l0            { path "${params.cohort_id}/attribution_comparison/L0" }
    ablation_bootstrap_l1            { path "${params.cohort_id}/attribution_comparison/L1" }
    ablation_bootstrap_l2            { path "${params.cohort_id}/attribution_comparison/L2" }
    ablation_bootstrap_l3            { path "${params.cohort_id}/attribution_comparison/L3" }

    ablation_gene_delta_l0           { path "${params.cohort_id}/ablation/gene_significance_rankings_delta/L0" }
    ablation_gene_delta_l1           { path "${params.cohort_id}/ablation/gene_significance_rankings_delta/L1" }
    ablation_gene_delta_l2           { path "${params.cohort_id}/ablation/gene_significance_rankings_delta/L2" }
    ablation_gene_delta_l3           { path "${params.cohort_id}/ablation/gene_significance_rankings_delta/L3" }
    ablation_gene_zattr_l0           { path "${params.cohort_id}/ablation/gene_significance_rankings_zattr/L0" }
    ablation_gene_zattr_l1           { path "${params.cohort_id}/ablation/gene_significance_rankings_zattr/L1" }
    ablation_gene_zattr_l2           { path "${params.cohort_id}/ablation/gene_significance_rankings_zattr/L2" }
    ablation_gene_zattr_l3           { path "${params.cohort_id}/ablation/gene_significance_rankings_zattr/L3" }
    ablation_variant_significance_l0 { path "${params.cohort_id}/ablation/variants_significance_rankings" }
    ablation_variant_significance_l1 { path "${params.cohort_id}/ablation/variants_significance_rankings" }
    ablation_variant_significance_l2 { path "${params.cohort_id}/ablation/variants_significance_rankings" }
    ablation_variant_significance_l3 { path "${params.cohort_id}/ablation/variants_significance_rankings" }

    ablation_comparison_summary      { path "${params.cohort_id}/ablation/comparison_levels" }

    epistasis_audit                  { path "${params.cohort_id}/epistasis/L3/epistasis_audit" }
    gene_interactions                { path "${params.cohort_id}/epistasis/L3/gene_interactions" }

    validation                       { path "${params.cohort_id}/validation" }

    pipeline_versions                { path "pipeline_info" }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
