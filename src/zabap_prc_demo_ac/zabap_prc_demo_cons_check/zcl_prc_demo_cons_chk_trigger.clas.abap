"! <p class="shorttext synchronized">Demo: Trigger the consistency check of contracts</p>
"!
"! One open check per contract: a contract whose checks are still open (red or
"! waiting, always in START) is checked again by processing all of them once
"! more; a contract without an open check gets a new one. A green check is
"! never touched - it is history.
"!
"! Writes processed objects and schedules bgPF: call CHECK in the save phase of
"! the caller's LUW (the service contract calls it in its additional save).
"! The run of ZCL_PRC_DEMO_CONS_CHECK_JOB does not use this class - a run
"! always creates its own objects.
CLASS zcl_prc_demo_cons_chk_trigger DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_contract,
             uuid TYPE sysuuid_x16,
             id   TYPE zprc_demo_srvctr-service_contract_id,
           END OF ty_contract,
           tt_contract TYPE STANDARD TABLE OF ty_contract WITH EMPTY KEY.

    " An open check: processed object and its contract
    TYPES: BEGIN OF ty_open_check,
             uuid          TYPE sysuuid_x16,
             contract_uuid TYPE sysuuid_x16,
           END OF ty_open_check,
           tt_open_check TYPE STANDARD TABLE OF ty_open_check WITH EMPTY KEY.

    TYPES tt_uuid TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    " What to do: process open checks again, create new ones
    TYPES: BEGIN OF ty_plan,
             check_again TYPE tt_uuid,
             create      TYPE zcl_prc_processing_api=>tt_create_processed_objects,
           END OF ty_plan.

    "! Checks the contracts again: open checks are processed again, the others
    "! get a new check. No COMMIT - the commit of the caller's LUW starts bgPF.
    "!
    "! @parameter i_contracts | Contracts to check.
    "! @raising   cx_bgmc     | bgPF could not be scheduled.
    CLASS-METHODS check IMPORTING i_contracts TYPE tt_contract
                        RAISING   cx_bgmc.

    "! The decision of CHECK, without database access: all open checks are
    "! processed again; every contract without an open check gets a new one.
    "!
    "! @parameter i_contracts   | Contracts to check.
    "! @parameter i_open_checks | Open checks of these contracts.
    "! @parameter r_plan        | Objects to process again and objects to create.
    CLASS-METHODS plan IMPORTING i_contracts   TYPE tt_contract
                                 i_open_checks TYPE tt_open_check
                       RETURNING VALUE(r_plan) TYPE ty_plan.
ENDCLASS.


CLASS zcl_prc_demo_cons_chk_trigger IMPLEMENTATION.

  METHOD check.
    IF i_contracts IS INITIAL.
      RETURN.
    ENDIF.

    DATA contract_uuids TYPE RANGE OF sysuuid_x16.
    contract_uuids = VALUE #( FOR c IN i_contracts ( sign = 'I' option = 'EQ' low = c-uuid ) ).

    " All open checks - several may exist (e.g. from runs), all are processed again
    DATA open_checks TYPE tt_open_check.
    SELECT FROM zi_prc_processedobject WITH PRIVILEGED ACCESS
      FIELDS UUID AS uuid, ExternalProcessedObjectUUID AS contract_uuid
      WHERE ProcessName                 =  @zcl_prc_demo_cons_check_proc=>co_process_name
        AND State                       <> @zif_prc_process=>co_finished
        AND ExternalProcessedObjectUUID IN @contract_uuids
      INTO CORRESPONDING FIELDS OF TABLE @open_checks.

    DATA(plan) = plan( i_contracts   = i_contracts
                       i_open_checks = open_checks ).

    IF plan-check_again IS NOT INITIAL.
      " Process again now: also before the retry time and with used-up retries
      zcl_prc_processing_api=>get_instance( )->process_asynchronously_bgpf(
          VALUE #( ( selname = zcl_prc_retry_job=>co_parameter-ignore_restart
                     kind    = if_apj_dt_exec_object=>parameter
                     sign    = 'I' option = 'EQ' low = abap_true )
                   ( LINES OF VALUE #( FOR u IN plan-check_again
                                       ( selname = zcl_prc_retry_job=>co_parameter-uuid
                                         kind    = if_apj_dt_exec_object=>select_option
                                         sign    = 'I' option = 'EQ' low = u ) ) ) ) ).
    ENDIF.

    IF plan-create IS NOT INITIAL.
      zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf( plan-create ).
    ENDIF.
  ENDMETHOD.


  METHOD plan.
    r_plan-check_again = VALUE #( FOR o IN i_open_checks ( o-uuid ) ).

    LOOP AT i_contracts INTO DATA(contract) WHERE uuid IS NOT INITIAL.
      IF line_exists( i_open_checks[ contract_uuid = contract-uuid ] )
         OR line_exists( r_plan-create[ processedObjectUUID = contract-uuid ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( processName         = zcl_prc_demo_cons_check_proc=>co_process_name
                      factoryClassName    = zcl_prc_demo_cons_check_proc=>co_class_name
                      processedObject     = contract-id
                      processedObjectUUID = contract-uuid ) TO r_plan-create.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
