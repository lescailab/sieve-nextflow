class SieveStepUtils {

    static List splitCsvValues(value) {
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

    static LinkedHashSet executionStepNames() {
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

    static String normalizeExecutionStep(rawStep) {
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

    static LinkedHashSet resolveExecuteSteps(stepValue) {
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
}
