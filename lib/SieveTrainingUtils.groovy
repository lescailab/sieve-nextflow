class SieveTrainingUtils {

    static Map extractTrainingParams(configPath) {
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
        def parsed = yaml.load(new File(configPath.toString()).text)
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

    static List buildTrainingGrid(baseTrainParams, lrValues, lambdaAttrValues, latentDimValues, hiddenDimValues, layerValues) {
        def lrList = SieveStepUtils.splitCsvValues(lrValues).collect { it as Double }
        def lambdaList = SieveStepUtils.splitCsvValues(lambdaAttrValues).collect { it as Double }
        def latentList = SieveStepUtils.splitCsvValues(latentDimValues).collect { it as Integer }
        def hiddenList = SieveStepUtils.splitCsvValues(hiddenDimValues).collect { it as Integer }
        def layerList = SieveStepUtils.splitCsvValues(layerValues).collect { it as Integer }

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
        int runCounter = 0

        lrList.each { lr ->
            lambdaList.each { lambda_attr ->
                latentList.each { latent_dim ->
                    hiddenList.each { hidden_dim ->
                        layerList.each { num_attention_layers ->
                            runCounter += 1
                            def runParams = new LinkedHashMap(baseTrainParams ?: [:])
                            runParams.putAll([
                                run_id: String.format('grid_%03d', runCounter),
                                lr: lr,
                                lambda_attr: lambda_attr,
                                latent_dim: latent_dim,
                                hidden_dim: hidden_dim,
                                num_attention_layers: num_attention_layers,
                            ])
                            grid << runParams
                        }
                    }
                }
            }
        }

        return grid
    }
}
