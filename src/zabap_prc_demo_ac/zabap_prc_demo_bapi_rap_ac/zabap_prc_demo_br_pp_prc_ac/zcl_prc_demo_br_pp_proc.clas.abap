"! <p class="shorttext synchronized">BAPI &amp; RAP 4: PRC process (BAPI A, then BAPI B)</p>
"!
"! START --(BAPI A: create legacy document)--> LEGACY_CREATED --(BAPI B: follow-up)--> FINISHED
"!
"! Each step runs after the RAP commit in its own session with its own commit.
"! So BAPI B finds the document of BAPI A on the database - which fails in the
"! same LUW (scenario 3). An error in a step - even MESSAGE X in the update task -
"! stops only this step of this order; it is resumed there later.
"! ABAP Cloud: the BAPIs are called via the released wrapper ZCL_PRC_DEMO_BR_BAPI_WRAP.
CLASS zcl_prc_demo_br_pp_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prc_process.

    ALIASES tt_transition FOR zif_prc_process~tt_transition.
    ALIASES ty_state      FOR zif_prc_process~ty_state.

    CONSTANTS co_legacy_created TYPE ty_state                VALUE 'LEGACY_CREATED'.
    CONSTANTS co_class_name     TYPE zprc_process_impl_class VALUE 'ZCL_PRC_DEMO_BR_PP_PROC'.
    CONSTANTS co_process_name   TYPE zprc_process_name       VALUE 'DEMO_BAPI_RAP'.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_br_pp_proc IMPLEMENTATION.

  METHOD zif_prc_process~get_transitions.
    r_transitions = VALUE tt_transition( ( start_state = zif_prc_process~co_start end_state = co_legacy_created )
                                         ( start_state = co_legacy_created        end_state = zif_prc_process~co_finished ) ).
  ENDMETHOD.


  METHOD zif_prc_process~get_transition_handler.
    " The handler of a state does the work that leads out of it
    CASE i_start_state.
      WHEN zif_prc_process~co_start.
        r_transition_handler = NEW lcl_create_legacy( ).
      WHEN co_legacy_created.
        r_transition_handler = NEW lcl_create_followup( ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_prc_process~get_url_for_processed_object.
    " No launchpad app is delivered for the demo BO
    CLEAR r_relative_url.
  ENDMETHOD.

ENDCLASS.
