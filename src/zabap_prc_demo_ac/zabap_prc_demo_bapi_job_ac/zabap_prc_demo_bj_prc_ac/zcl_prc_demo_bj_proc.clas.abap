"! <p class="shorttext synchronized">BAPI &amp; Jobs: PRC process (BAPI A, then BAPI B)</p>
"!
"! START --(BAPI A)--> LEGACY_CREATED --(BAPI B)--> FINISHED
"!
"! Same chain as the job without PRC - but every order and every step runs in
"! its own session with its own commit. The provoked error modes are job
"! parameters, not order data, so they travel in the payload.
"! ABAP Cloud: the BAPIs are called via the released wrapper ZCL_PRC_DEMO_BJ_BAPI_WRAP.
CLASS zcl_prc_demo_bj_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.
    ALIASES ty_state      FOR zif_prc_process~ty_state.

    TYPES: BEGIN OF ty_payload,
             mode_a TYPE zprc_demo_bj_error_mode,
             mode_b TYPE zprc_demo_bj_error_mode,
           END OF ty_payload.

    CONSTANTS co_legacy_created TYPE ty_state                VALUE 'LEGACY_CREATED'.
    CONSTANTS co_class_name     TYPE zprc_process_impl_class VALUE 'ZCL_PRC_DEMO_BJ_PROC'.
    CONSTANTS co_process_name   TYPE zprc_process_name       VALUE 'DEMO_BAPI_JOB'.

    "! @parameter i_payload | Error modes for both BAPIs
    "! @parameter r_json    | The payload as JSON
    CLASS-METHODS to_payload
      IMPORTING i_payload     TYPE ty_payload
      RETURNING VALUE(r_json) TYPE zprc_payload_json.

    "! @parameter i_json    | The payload as JSON
    "! @parameter r_payload | Error modes for both BAPIs; initial if the JSON is invalid
    CLASS-METHODS from_payload
      IMPORTING i_json           TYPE zprc_payload_json
      RETURNING VALUE(r_payload) TYPE ty_payload.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_bj_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition( ( start_state = zif_prc_process~co_start end_state = co_legacy_created )
                                         ( start_state = co_legacy_created        end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    CASE i_start_state.
      WHEN zif_prc_process~co_start.
        r_transition_handler = NEW lcl_create_legacy( ).
      WHEN co_legacy_created.
        r_transition_handler = NEW lcl_create_followup( ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    CLEAR r_relative_url.
  ENDMETHOD.


  METHOD to_payload.
    r_json = xco_cp_json=>data->from_abap( i_payload )->to_string( ).
  ENDMETHOD.


  METHOD from_payload.
    CHECK i_json IS NOT INITIAL.
    TRY.
        xco_cp_json=>data->from_string( i_json )->write_to( REF #( r_payload ) ).
      CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
        " Invalid payload: no provoked error
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
