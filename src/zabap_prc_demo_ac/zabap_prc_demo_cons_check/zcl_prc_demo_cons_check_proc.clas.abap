"! <p class="shorttext synchronized">Demo: Consistency check of a service contract</p>
"!
"! Demo of findings: a consistency check that is expected to find errors and
"! collects all of them instead of stopping at the first one.
"!
"! <h2>Rule</h2>
"! An equipment must not be in two released service contracts
"! (ZCL_PRC_DEMO_CONS_CHECKER). A contract can become inconsistent without being
"! changed - when another contract with the same equipment is released. That is
"! why the check runs in the Processing Center besides the validation of the
"! contract.
"!
"! <h2>Process</h2>
"! <ul>
"! <li>START -> FINISHED: the contract is consistent.</li>
"! <li>START -> START: the contract has findings. Every finding is added with
"!     I_FAIL_STEP = ABAP_FALSE, so the step does not fail: it is committed
"!     with the error status of the contract, shows all findings with a
"!     summary as header, and keeps the object erroneous until it is checked
"!     again.</li>
"! </ul>
"! The error status of the contract (E / N) is set in both cases - that is the
"! change that a failing step would roll back.
"!
"! <h2>Triggers</h2>
"! <ul>
"! <li>Actions Check and Release of a contract: an open (red) check of the
"!     contract is processed again, else a new one is created
"!     (ZCL_PRC_DEMO_CONS_CHECK_TRIGGER).</li>
"! <li>Run for all unreleased contracts from the list report
"!     (ZCL_PRC_DEMO_CONS_CHECK_JOB): always new processed objects of that run.</li>
"! </ul>
CLASS zcl_prc_demo_cons_check_proc DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.
    ALIASES ty_state      FOR zif_prc_process~ty_state.

    CONSTANTS co_class_name   TYPE zprc_process_impl_class VALUE 'ZCL_PRC_DEMO_CONS_CHECK_PROC'.
    " Demo processes start with DEMO_, test processes with TEST_ (not productive)
    CONSTANTS co_process_name TYPE zprc_process_name       VALUE 'DEMO_SRV_CTR_CONS_CHECK'.

    " Error status of the service contract (domain ZPRC_DEMO_ERROR_STATUS)
    CONSTANTS: BEGIN OF error_status,
                 contains_error TYPE zprc_demo_error_status VALUE 'E',
                 no_error       TYPE zprc_demo_error_status VALUE 'N',
               END OF error_status.
ENDCLASS.


CLASS zcl_prc_demo_cons_check_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition(
        ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_start )      " findings
        ( start_state = zif_prc_process~co_start end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    CASE i_start_state.
      WHEN zif_prc_process~co_start.
        r_transition_handler = NEW lcl_check( ).
      WHEN OTHERS.
        " No handler: the engine reports ZPRC_PROCESS_MESSAGE/007
    ENDCASE.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    " The processed object carries the contract UUID as external UUID
    IF i_processed_object_uuid IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        cl_system_uuid=>convert_uuid_x16_static( EXPORTING uuid     = i_processed_object_uuid
                                                 IMPORTING uuid_c36 = DATA(contract_uuid) ).
      CATCH cx_uuid_error.
        " No link rather than a runtime error in the app
        RETURN.
    ENDTRY.
    " Intent of the deployed contract app (no draft, key UUID)
    r_relative_url = |#ABAP_PRC_Demo_ServiceContract-show&/ServiceContract({ to_lower( contract_uuid ) })|.
  ENDMETHOD.

ENDCLASS.
