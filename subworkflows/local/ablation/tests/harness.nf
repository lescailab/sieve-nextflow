include { ABLATION } from "../main"

workflow TEST_ABLATION {

    take:
    ch_selection_meta
    ch_preprocessed_keyed
    ch_sex_map_keyed
    ch_best_params_map_keyed
    ch_null_preprocessed_keyed

    main:
    ABLATION(
        ch_selection_meta,
        ch_preprocessed_keyed,
        ch_sex_map_keyed,
        ch_best_params_map_keyed,
        ch_null_preprocessed_keyed
    )

    emit:
    versions = ABLATION.out.versions
}
