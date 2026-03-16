include { TRAIN_AND_EXPLAIN } from "../main"

workflow TEST_TRAIN_AND_EXPLAIN {

    take:
    ch_selection_meta
    ch_preprocessed_keyed
    ch_sex_map_keyed
    ch_best_params_path_keyed
    ch_best_params_map_keyed

    main:
    TRAIN_AND_EXPLAIN(
        ch_selection_meta,
        ch_preprocessed_keyed,
        ch_sex_map_keyed,
        ch_best_params_path_keyed,
        ch_best_params_map_keyed
    )

    emit:
    versions = TRAIN_AND_EXPLAIN.out.versions
}
