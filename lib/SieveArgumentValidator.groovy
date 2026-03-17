class SieveArgumentValidator {

    static void validateSieveArguments(
        vcf,
        phenotypes,
        genomeBuild,
        inferSex,
        knownSex,
        sexMap,
        preprocessedData,
        bestParams,
        bestCheckpoint,
        checkpointConfig,
        executeStep,
        log,
        Closure errorFn
    ) {
        final Closure fail = errorFn ?: { String message -> throw new IllegalArgumentException(message) }

        def selectedSteps = SieveStepUtils.resolveExecuteSteps(executeStep)

        def targetSex = selectedSteps.contains('sex')
        def targetPreprocess = selectedSteps.contains('preprocess')
        def targetGrid = selectedSteps.contains('grid')
        def targetCv = selectedSteps.contains('cv')
        def targetExplain = selectedSteps.contains('explain')
        def targetAblation = selectedSteps.contains('ablation')
        def targetNull = selectedSteps.contains('null')
        def targetEpistasis = selectedSteps.contains('epistasis')
        def targetValidation = selectedSteps.contains('validation')

        def useProvidedPreprocessed = preprocessedData as boolean
        def useProvidedBestCheckpoint = (bestCheckpoint && checkpointConfig) as boolean

        def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull
        def needBestCheckpoint = targetCv || needExplain
        def needBestParams = targetGrid || targetAblation || targetNull || (needBestCheckpoint && !useProvidedBestCheckpoint)
        def needPreprocessed = targetPreprocess || needBestParams || needExplain || (needBestCheckpoint && !useProvidedBestCheckpoint)
        def needSexMap = targetSex || needBestParams || (needPreprocessed && !useProvidedPreprocessed)

        if ((bestCheckpoint && !checkpointConfig) || (!bestCheckpoint && checkpointConfig)) {
            fail.call('Parameters --best_checkpoint and --checkpoint_config must be provided together.')
        }

        if (bestCheckpoint) {
            assertExistingFile(bestCheckpoint, '--best_checkpoint', fail)
            if (!bestCheckpoint.toString().endsWith('.pt')) {
                fail.call('The --best_checkpoint input should be a .pt file.')
            }
        }

        if (checkpointConfig) {
            assertExistingFile(checkpointConfig, '--checkpoint_config', fail)
            if (!(checkpointConfig.toString().endsWith('.yaml') || checkpointConfig.toString().endsWith('.yml'))) {
                fail.call('The --checkpoint_config input should end with .yaml or .yml.')
            }
        }

        if (bestParams) {
            assertExistingFile(bestParams, '--best_params', fail)
            if (!(bestParams.toString().endsWith('.yaml') || bestParams.toString().endsWith('.yml'))) {
                fail.call('The --best_params input should end with .yaml or .yml.')
            }
        }

        if (preprocessedData) {
            assertExistingFile(preprocessedData, '--preprocessed_data', fail)
            if (!preprocessedData.toString().endsWith('.pt')) {
                fail.call('The --preprocessed_data input must end with .pt')
            }
        }

        if (knownSex) {
            assertExistingFile(knownSex, '--known_sex', fail)
        }

        if (sexMap) {
            assertExistingFile(sexMap, '--sex_map', fail)
            if (inferSex) {
                log?.warn('Both --sex_map and --infer_sex were provided. The pipeline will use --sex_map and skip sex inference.')
            }
        }

        def needsRawVcfForSex = needSexMap && !sexMap
        def needsRawVcfForPreprocess = needPreprocessed && !useProvidedPreprocessed
        def needsRawVcf = needsRawVcfForSex || needsRawVcfForPreprocess
        def needsPhenotypes = needPreprocessed && !useProvidedPreprocessed

        if (needSexMap && !sexMap && !inferSex) {
            fail.call('The selected execution steps require sex information. Provide --sex_map or set --infer_sex true.')
        }

        def willRunSexInference = needSexMap && !sexMap && inferSex
        if (knownSex && !willRunSexInference) {
            log?.warn('Parameter --known_sex is only used when the pipeline runs sex inference. It will be ignored for the current inputs and selected steps.')
        }

        if (needsRawVcf) {
            if (!vcf) {
                fail.call('Missing required argument: --vcf (required by selected execution steps).')
            }

            if (!pathExists(vcf)) {
                fail.call("The file provided to --vcf does not exist: ${vcf}")
            }

            if (!vcf.toString().endsWith('.vcf.gz')) {
                fail.call('The --vcf input must end with .vcf.gz')
            }

            def tbiIndex = "${vcf}.tbi"
            def csiIndex = "${vcf}.csi"
            if (!pathExists(tbiIndex) && !pathExists(csiIndex)) {
                fail.call("Could not find a VCF index for '${vcf}'. Expected '${vcf}.tbi' or '${vcf}.csi'.")
            }
        }

        if (needsPhenotypes) {
            if (!phenotypes) {
                fail.call('Missing required argument: --phenotypes (required when preprocessing runs).')
            }

            if (!pathExists(phenotypes)) {
                fail.call("The file provided to --phenotypes does not exist: ${phenotypes}")
            }
        }

        if (needsRawVcf) {
            def allowedBuilds = ['GRCh37', 'GRCh38']
            if (!(genomeBuild in allowedBuilds)) {
                fail.call("Invalid --genome_build '${genomeBuild}'. Supported values: ${allowedBuilds.join(', ')}")
            }
        }
    }

    private static void assertExistingFile(pathLike, String paramName, Closure fail) {
        if (!pathExists(pathLike)) {
            fail.call("The file provided to ${paramName} does not exist: ${pathLike}")
        }
    }

    private static boolean pathExists(pathLike) {
        if (!pathLike) {
            return false
        }
        try {
            return java.nio.file.Files.exists(asNioPath(pathLike))
        } catch (Exception ignored) {
            return false
        }
    }

    private static asNioPath(pathLike) {
        if (pathLike instanceof java.nio.file.Path) {
            return pathLike
        }
        return nextflow.file.FileHelper.asPath(pathLike.toString())
    }
}
