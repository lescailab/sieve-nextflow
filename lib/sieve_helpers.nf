/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Local helper functions for the SIEVE pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def splitCsvValues(value) {
    if (value == null) {
        return []
    }
    if (value instanceof java.util.List) {
        return value
    }
    return value
        .toString()
        .split(',')
        .collect { entry -> entry.trim() }
        .findAll { entry -> entry }
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
    ] as java.util.LinkedHashSet
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
        .collect { entry -> normalizeExecutionStep(entry) }
        .findAll { entry -> entry }

    if (!requested) {
        return allSteps
    }

    if (requested.contains('all')) {
        return allSteps
    }

    def invalid = requested.findAll { entry -> !(entry in allSteps) }.unique()
    if (invalid) {
        throw new IllegalArgumentException("Invalid --execute_step value(s): ${invalid.join(', ')}. Allowed values: ${allSteps.join(', ')}")
    }

    return requested as java.util.LinkedHashSet
}

def asNioPath(pathLike) {
    if (pathLike instanceof java.nio.file.Path) {
        return pathLike
    }
    return nextflow.file.FileHelper.asPath(pathLike.toString())
}

def pathExists(pathLike) {
    if (!pathLike) {
        return false
    }
    try {
        return java.nio.file.Files.exists(asNioPath(pathLike))
    } catch (Exception _ignored) {
        return false
    }
}

def assertExistingFile(pathLike, paramName, failFn) {
    if (!pathExists(pathLike)) {
        failFn.call("The file provided to ${paramName} does not exist: ${pathLike}")
    }
}

def validateSieveArguments(
    vcf,
    phenotypes,
    genomeBuild,
    inferSex,
    sexMap,
    preprocessedData,
    bestParams,
    bestCheckpoint,
    checkpointConfig,
    executeStep,
    logHandle,
    errorFn
) {
    def fail = errorFn ?: { message -> throw new IllegalArgumentException(message) }

    def selectedSteps = resolveExecuteSteps(executeStep)

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

    if (sexMap) {
        assertExistingFile(sexMap, '--sex_map', fail)
        if (inferSex) {
            logHandle?.warn('Both --sex_map and --infer_sex were provided. The pipeline will use --sex_map and skip sex inference.')
        }
    }

    def needsRawVcfForSex = needSexMap && !sexMap
    def needsRawVcfForPreprocess = needPreprocessed && !useProvidedPreprocessed
    def needsRawVcf = needsRawVcfForSex || needsRawVcfForPreprocess
    def needsPhenotypes = needPreprocessed && !useProvidedPreprocessed

    if (needSexMap && !sexMap && !inferSex) {
        fail.call('The selected execution steps require sex information. Provide --sex_map or set --infer_sex true.')
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

def extractTrainingParams(configPath) {
    def allowedKeys = [
        'epochs',
        'batch_size',
        'chunk_size',
        'aggregation_method',
        'gradient_accumulation_steps',
        'gradient_clip',
        'seed',
        'device',
        'early_stopping',
        'hidden_dim',
        'num_attention_layers',
        'lr',
        'lambda_attr',
        'latent_dim',
        'annotation_level',
        'num_heads',
        'num_workers',
        'max_variants_per_batch',
    ] as Set

    def yaml = new org.yaml.snakeyaml.Yaml()
    def parsed = null
    def resolvedPath = asNioPath(configPath)
    java.nio.file.Files.newInputStream(resolvedPath).withCloseable { inputStream ->
        parsed = yaml.load(inputStream)
    }
    parsed = parsed instanceof Map ? parsed : [:]

    if (parsed.hyperparameters instanceof Map) {
        parsed = parsed.hyperparameters
    }

    def trainingParams = [:]
    parsed.each { key, value ->
        if (value != null) {
            def normalizedKey = key.toString().replace('-', '_')
            if (normalizedKey in allowedKeys) {
                trainingParams[normalizedKey] = value
            }
        }
    }

    return trainingParams
}

def buildTrainingGrid(baseTrainParams, lrValues, lambdaAttrValues, latentDimValues, hiddenDimValues, layerValues) {
    def lrList = splitCsvValues(lrValues).collect { value -> value as Double }
    def lambdaList = splitCsvValues(lambdaAttrValues).collect { value -> value as Double }
    def latentList = splitCsvValues(latentDimValues).collect { value -> value as Integer }
    def hiddenList = splitCsvValues(hiddenDimValues).collect { value -> value as Integer }
    def layerList = splitCsvValues(layerValues).collect { value -> value as Integer }

    if (!lrList || !lambdaList || !latentList || !hiddenList || !layerList) {
        def missing = []
        if (!lrList) {
            missing << 'grid_lr'
        }
        if (!lambdaList) {
            missing << 'grid_lambda_attr'
        }
        if (!latentList) {
            missing << 'grid_latent_dim'
        }
        if (!hiddenList) {
            missing << 'grid_hidden_dim'
        }
        if (!layerList) {
            missing << 'grid_num_attention_layers'
        }
        throw new IllegalArgumentException("Training grid values cannot be empty: ${missing.join(', ')}")
    }

    def grid = []
    def runCounter = 0

    lrList.each { lr ->
        lambdaList.each { lambdaAttr ->
            latentList.each { latentDim ->
                hiddenList.each { hiddenDim ->
                    layerList.each { numAttentionLayers ->
                        runCounter += 1
                        def runParams = new java.util.LinkedHashMap(baseTrainParams ?: [:])
                        runParams.putAll([
                            run_id: String.format('grid_%03d', runCounter),
                            lr: lr,
                            lambda_attr: lambdaAttr,
                            latent_dim: latentDim,
                            hidden_dim: hiddenDim,
                            num_attention_layers: numAttentionLayers,
                        ])
                        grid << runParams
                    }
                }
            }
        }
    }

    return grid
}

def getWorkflowVersionString() {
    def versionString = ''
    if (workflow.manifest.version) {
        def prefixV = workflow.manifest.version[0] != 'v' ? 'v' : ''
        versionString += "${prefixV}${workflow.manifest.version}"
    }

    if (workflow.commitId) {
        def gitShortsha = workflow.commitId.substring(0, 7)
        versionString += "-g${gitShortsha}"
    }

    return versionString
}

def processVersionsFromYAML(yamlFile) {
    def yaml = new org.yaml.snakeyaml.Yaml()
    def yamlText = java.nio.file.Files.readString(asNioPath(yamlFile))
    def versions = yaml.load(yamlText).collectEntries { key, value -> [key.toString().tokenize(':')[-1], value] }
    return yaml.dumpAsMap(versions).trim()
}

def processVersionTupleToYAML(versionEntry) {
    def yaml = new org.yaml.snakeyaml.Yaml()
    def tupleEntry = versionEntry as java.util.List
    def toolVersions = new java.util.LinkedHashMap()
    toolVersions.put(tupleEntry[1].toString(), tupleEntry[2].toString())
    def processVersions = new java.util.LinkedHashMap()
    processVersions.put(tupleEntry[0].toString(), toolVersions)
    return yaml.dumpAsMap(processVersions).trim()
}

def normalizeVersionEntry(versionEntry) {
    if (versionEntry == null) {
        return null
    }
    if (versionEntry instanceof java.nio.file.Path || versionEntry instanceof java.io.File) {
        return processVersionsFromYAML(versionEntry)
    }
    if (versionEntry instanceof java.util.List && versionEntry.size() == 3) {
        return processVersionTupleToYAML(versionEntry)
    }
    return versionEntry.toString().trim()
}

def workflowVersionToYAML() {
    return """
    Workflow:
        ${workflow.manifest.name}: ${getWorkflowVersionString()}
        Nextflow: ${workflow.nextflow.version}
    """.stripIndent().trim()
}

def softwareVersionsToYAML(chVersions) {
    return chVersions
        .map { versionEntry -> normalizeVersionEntry(versionEntry) }
        .filter { versionEntry -> versionEntry }
        .unique()
        .mix(channel.of(workflowVersionToYAML()))
}

def imNotification(summaryParams, hookUrl) {
    def summary = [:]
    summaryParams
        .keySet()
        .sort()
        .each { group ->
            summary << summaryParams[group]
        }

    def miscFields = [:]
    miscFields['start'] = workflow.start
    miscFields['complete'] = workflow.complete
    miscFields['scriptfile'] = workflow.scriptFile
    miscFields['scriptid'] = workflow.scriptId
    if (workflow.repository) {
        miscFields['repository'] = workflow.repository
    }
    if (workflow.commitId) {
        miscFields['commitid'] = workflow.commitId
    }
    if (workflow.revision) {
        miscFields['revision'] = workflow.revision
    }
    miscFields['nxf_version'] = workflow.nextflow.version
    miscFields['nxf_build'] = workflow.nextflow.build
    miscFields['nxf_timestamp'] = workflow.nextflow.timestamp

    def msgFields = [:]
    msgFields['version'] = getWorkflowVersionString()
    msgFields['runName'] = workflow.runName
    msgFields['success'] = workflow.success
    msgFields['dateComplete'] = workflow.complete
    msgFields['duration'] = workflow.duration
    msgFields['exitStatus'] = workflow.exitStatus
    msgFields['errorMessage'] = workflow.errorMessage ?: 'None'
    msgFields['errorReport'] = workflow.errorReport ?: 'None'
    msgFields['commandLine'] = workflow.commandLine.replaceFirst(/ +--hook_url +[^ ]+/, '')
    msgFields['projectDir'] = workflow.projectDir
    msgFields['summary'] = summary << miscFields

    def engine = new groovy.text.GStringTemplateEngine()
    def jsonPath = hookUrl.contains('hooks.slack.com') ? 'slackreport.json' : 'adaptivecard.json'
    def jsonTemplateFile = new File("${workflow.projectDir}/assets/${jsonPath}")
    def jsonTemplate = engine.createTemplate(jsonTemplateFile).make(msgFields)
    def jsonMessage = jsonTemplate.toString()

    def post = new java.net.URL(hookUrl).openConnection()
    post.setRequestMethod('POST')
    post.setDoOutput(true)
    post.setRequestProperty('Content-Type', 'application/json')
    post.getOutputStream().write(jsonMessage.getBytes('UTF-8'))
    def postRC = post.getResponseCode()
    if (!postRC.equals(200)) {
        log.warn(post.getErrorStream().getText())
    }
}
