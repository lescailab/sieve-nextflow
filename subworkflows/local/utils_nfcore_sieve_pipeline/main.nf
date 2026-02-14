//
// Subworkflow with functionality specific to the nf-core/sieve pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { completionEmail } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args // array: List of positional nextflow CLI args
    outdir            // string: Path to output directory
    vcf               // string: Path to bgzipped indexed VCF
    phenotypes        // string: Path to phenotype TSV
    genome_build      // string: GRCh37 or GRCh38
    infer_sex         // boolean: whether to infer sex when sex_map not provided
    sex_map           // string: Optional precomputed sex map TSV
    preprocessed_data // string: Optional preprocessed dataset (.pt)
    best_params       // string: Optional best-parameter YAML to skip grid search
    best_checkpoint   // string: Optional model checkpoint (.pt) to skip CV
    checkpoint_config // string: Optional config YAML paired with --best_checkpoint
    execute_step      // string: Optional comma-separated list of steps to execute
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    before_text = """
-
\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/sieve ${workflow.manifest.version}\033[0m
-
\033[2m----------------------------------------------------\033[0m-
"""

    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/','')}"}.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/sieve/blob/master/CITATIONS.md
"""

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --vcf cohort.vcf.gz --phenotypes phenotypes.tsv --genome_build GRCh38 --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command
    )

    validateSieveArguments(
        vcf,
        phenotypes,
        genome_build,
        infer_sex,
        sex_map,
        preprocessed_data,
        best_params,
        best_checkpoint,
        checkpoint_config,
        execute_step
    )

    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           // string: email address
    email_on_fail   // string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          // path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        // string: hook URL for notifications

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: 'nextflow_schema.json')

    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error 'Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting'
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def validateSieveArguments(vcf, phenotypes, genome_build, infer_sex, sex_map, preprocessed_data, best_params, best_checkpoint, checkpoint_config, execute_step) {
    def selectedSteps = resolveExecuteSteps(execute_step)

    def targetSex = selectedSteps.contains('sex')
    def targetPreprocess = selectedSteps.contains('preprocess')
    def targetGrid = selectedSteps.contains('grid')
    def targetCv = selectedSteps.contains('cv')
    def targetExplain = selectedSteps.contains('explain')
    def targetAblation = selectedSteps.contains('ablation')
    def targetNull = selectedSteps.contains('null')
    def targetEpistasis = selectedSteps.contains('epistasis')
    def targetValidation = selectedSteps.contains('validation')

    def useProvidedPreprocessed = preprocessed_data as boolean
    def useProvidedBestCheckpoint = (best_checkpoint && checkpoint_config) as boolean

    def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull
    def needBestCheckpoint = targetCv || needExplain
    def needBestParams = targetGrid || targetAblation || targetNull || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needPreprocessed = targetPreprocess || needBestParams || needExplain || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needSexMap = targetSex || needBestParams || (needPreprocessed && !useProvidedPreprocessed)

    if ((best_checkpoint && !checkpoint_config) || (!best_checkpoint && checkpoint_config)) {
        error('Parameters --best_checkpoint and --checkpoint_config must be provided together.')
    }

    if (best_checkpoint) {
        assertExistingFile(best_checkpoint, '--best_checkpoint')
        if (!best_checkpoint.toString().endsWith('.pt')) {
            error('The --best_checkpoint input should be a .pt file.')
        }
    }

    if (checkpoint_config) {
        assertExistingFile(checkpoint_config, '--checkpoint_config')
        if (!(checkpoint_config.toString().endsWith('.yaml') || checkpoint_config.toString().endsWith('.yml'))) {
            error('The --checkpoint_config input should end with .yaml or .yml.')
        }
    }

    if (best_params) {
        assertExistingFile(best_params, '--best_params')
        if (!(best_params.toString().endsWith('.yaml') || best_params.toString().endsWith('.yml'))) {
            error('The --best_params input should end with .yaml or .yml.')
        }
    }

    if (preprocessed_data) {
        assertExistingFile(preprocessed_data, '--preprocessed_data')
        if (!preprocessed_data.toString().endsWith('.pt')) {
            error('The --preprocessed_data input must end with .pt')
        }
    }

    if (sex_map) {
        assertExistingFile(sex_map, '--sex_map')
        if (infer_sex) {
            log.warn('Both --sex_map and --infer_sex were provided. The pipeline will use --sex_map and skip sex inference.')
        }
    }

    def needsRawVcfForSex = needSexMap && !sex_map
    def needsRawVcfForPreprocess = needPreprocessed && !useProvidedPreprocessed
    def needsRawVcf = needsRawVcfForSex || needsRawVcfForPreprocess
    def needsPhenotypes = needPreprocessed && !useProvidedPreprocessed

    if (needSexMap && !sex_map && !infer_sex) {
        error('The selected execution steps require sex information. Provide --sex_map or set --infer_sex true.')
    }

    if (needsRawVcf) {
        if (!vcf) {
            error('Missing required argument: --vcf (required by selected execution steps).')
        }

        def vcfFile = new File(vcf.toString())
        if (!vcfFile.exists()) {
            error("The file provided to --vcf does not exist: ${vcf}")
        }

        if (!vcf.toString().endsWith('.vcf.gz')) {
            error('The --vcf input must end with .vcf.gz')
        }

        def tbiIndex = new File(vcf.toString() + '.tbi')
        def csiIndex = new File(vcf.toString() + '.csi')
        if (!tbiIndex.exists() && !csiIndex.exists()) {
            error("Could not find a VCF index for '${vcf}'. Expected '${vcf}.tbi' or '${vcf}.csi'.")
        }
    }

    if (needsPhenotypes) {
        if (!phenotypes) {
            error('Missing required argument: --phenotypes (required when preprocessing runs).')
        }

        def phenotypesFile = new File(phenotypes.toString())
        if (!phenotypesFile.exists()) {
            error("The file provided to --phenotypes does not exist: ${phenotypes}")
        }
    }

    if (needsRawVcf) {
        def allowedBuilds = ['GRCh37', 'GRCh38']
        if (!(genome_build in allowedBuilds)) {
            error("Invalid --genome_build '${genome_build}'. Supported values: ${allowedBuilds.join(', ')}")
        }
    }

}

def assertExistingFile(pathLike, paramName) {
    def target = new File(pathLike.toString())
    if (!target.exists()) {
        error("The file provided to ${paramName} does not exist: ${pathLike}")
    }
}

def splitCsvValues(value) {
    if (value == null) {
        return []
    }
    if (value instanceof List) {
        return value
    }
    return value
        .toString()
        .split(',')
        .collect { it.trim() }
        .findAll { it }
}

def executionStepNames() {
    return [
        'sex',
        'preprocess',
        'grid',
        'cv',
        'explain',
        'ablation',
        'null',
        'epistasis',
        'validation',
        'plots',
    ] as LinkedHashSet
}

def normalizeExecutionStep(rawStep) {
    if (rawStep == null) {
        return null
    }

    def step = rawStep
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(/[\s-]+/, '_')

    def aliases = [
        all: 'all',
        sex: 'sex',
        sex_map: 'sex',
        infer_sex: 'sex',
        preprocess: 'preprocess',
        preprocessing: 'preprocess',
        preprocessed: 'preprocess',
        grid: 'grid',
        grid_search: 'grid',
        best_params: 'grid',
        hyperparameter_search: 'grid',
        cv: 'cv',
        cross_fold: 'cv',
        cross_validation: 'cv',
        checkpoint_selection: 'cv',
        explain: 'explain',
        explainability: 'explain',
        ablation: 'ablation',
        ablation_experiment: 'ablation',
        null: 'null',
        null_model: 'null',
        null_baseline: 'null',
        epistasis: 'epistasis',
        epistasis_validation: 'epistasis',
        validation: 'validation',
        discoveries: 'validation',
        discovery_validation: 'validation',
        plots: 'plots',
        collect_plots: 'plots',
    ]

    return aliases.containsKey(step) ? aliases[step] : step
}

def resolveExecuteSteps(stepValue) {
    def allSteps = executionStepNames()
    def requested = splitCsvValues(stepValue)
        .collect { normalizeExecutionStep(it) }
        .findAll { it }

    if (!requested) {
        return allSteps
    }

    if (requested.contains('all')) {
        return allSteps
    }

    def invalid = requested.findAll { !(it in allSteps) }.unique()
    if (invalid) {
        throw new IllegalArgumentException("Invalid --execute_step value(s): ${invalid.join(', ')}. Allowed values: ${allSteps.join(', ')}")
    }

    return requested as LinkedHashSet
}
