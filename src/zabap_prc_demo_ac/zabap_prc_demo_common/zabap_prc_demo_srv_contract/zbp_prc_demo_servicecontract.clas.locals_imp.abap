"! Contracts whose consistency check starts in the Processing Center with the save -
"! one buffer per action that fills it, cleared in CLEANUP
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA check_consistency TYPE zcl_prc_demo_cons_chk_trigger=>tt_contract.
    CLASS-DATA release           TYPE zcl_prc_demo_cons_chk_trigger=>tt_contract.

    CLASS-METHODS clear.
ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.
  METHOD clear.
    CLEAR: check_consistency, release.
  ENDMETHOD.
ENDCLASS.


"! The consistency rule (ZCL_PRC_DEMO_CONS_CHECKER) applied to contracts in the
"! transactional buffer - shared by validations, determinations and actions
CLASS lcl_consistency DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_result,
             uuid             TYPE sysuuid_x16,
             contract_id      TYPE zprc_demo_srvctr-service_contract_id,
             lifecycle_status TYPE zprc_demo_lifecycle_status,
             error_status     TYPE zprc_demo_error_status,
             conflicts        TYPE zcl_prc_demo_cons_checker=>tt_conflict,
           END OF ty_result,
           tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    TYPES tt_uuid            TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    TYPES tt_behv_message    TYPE STANDARD TABLE OF REF TO if_abap_behv_message WITH EMPTY KEY.
    TYPES tt_contract_result TYPE TABLE FOR READ RESULT zr_prc_demo_servicecontract\\ServiceContract.

    "! Checks the contracts as they are in the buffer
    CLASS-METHODS check IMPORTING i_contracts      TYPE tt_uuid
                        RETURNING VALUE(r_results) TYPE tt_result.

    "! Sets the error status of the contracts to the result of the check.
    "!
    "! @parameter i_results | Results of CHECK.
    "! @parameter i_always  | ABAP_TRUE: also if unchanged - the contract is part of the save
    "!                        and its check starts there (actions); else only if it differs.
    CLASS-METHODS set_error_status IMPORTING i_results TYPE tt_result
                                             i_always  TYPE abap_bool DEFAULT abap_false.
ENDCLASS.


CLASS lcl_consistency IMPLEMENTATION.

  METHOD check.
    READ ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContract
        FIELDS ( ServiceContractID LifecycleStatus ErrorStatus )
        WITH VALUE #( FOR u IN i_contracts ( UUID = u ) )
        RESULT DATA(contracts)
      ENTITY ServiceContract BY \_ServiceContractItem
        FIELDS ( ParentUUID ItemNumber EquipmentId )
        WITH VALUE #( FOR u IN i_contracts ( UUID = u ) )
        RESULT DATA(items).

    LOOP AT contracts INTO DATA(contract).
      APPEND VALUE #( uuid             = contract-UUID
                      contract_id      = contract-ServiceContractID
                      lifecycle_status = contract-LifecycleStatus
                      error_status     = contract-ErrorStatus
                      conflicts        = zcl_prc_demo_cons_checker=>find_conflicts(
                                             i_contract_uuid = contract-UUID
                                             i_items         = VALUE #( FOR i IN items WHERE ( ParentUUID = contract-UUID )
                                                                        ( item_number = i-ItemNumber
                                                                          equipment   = i-EquipmentId ) ) ) )
             TO r_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_error_status.
    DATA updates TYPE TABLE FOR UPDATE zr_prc_demo_servicecontract\\ServiceContract.
    LOOP AT i_results INTO DATA(result).
      DATA(error_status) = COND zprc_demo_error_status(
                               WHEN result-conflicts IS INITIAL
                               THEN zcl_prc_demo_cons_check_proc=>error_status-no_error
                               ELSE zcl_prc_demo_cons_check_proc=>error_status-contains_error ).
      IF i_always = abap_true OR error_status <> result-error_status.
        APPEND VALUE #( UUID = result-uuid ErrorStatus = error_status ) TO updates.
      ENDIF.
    ENDLOOP.
    IF updates IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContract UPDATE FIELDS ( ErrorStatus ) WITH updates.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_ServiceContract DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ServiceContract RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ServiceContract RESULT result.

    METHODS adjustViaSelectOptions FOR MODIFY
      IMPORTING keys FOR ACTION ServiceContract~adjustViaSelectOptions RESULT result.

    METHODS checkConsistency FOR MODIFY
      IMPORTING keys FOR ACTION ServiceContract~checkConsistency RESULT result.

    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION ServiceContract~release RESULT result.

    METHODS checkAllConsistency FOR MODIFY
      IMPORTING keys FOR ACTION ServiceContract~checkAllConsistency RESULT result.

    METHODS checkReleasedEquipment FOR VALIDATE ON SAVE
      IMPORTING keys FOR ServiceContract~checkReleasedEquipment.

    METHODS setErrorStatus FOR DETERMINE ON SAVE
      IMPORTING keys FOR ServiceContract~setErrorStatus.

    "! The conflicts as RAP messages of the given severity
    METHODS to_behv_messages IMPORTING i_conflicts       TYPE zcl_prc_demo_cons_checker=>tt_conflict
                                       i_severity        TYPE if_abap_behv_message=>t_severity
                             RETURNING VALUE(r_messages) TYPE lcl_consistency=>tt_behv_message.

    "! Returns the contracts as they are now in the buffer
    METHODS read_result IMPORTING i_keys          TYPE lcl_consistency=>tt_uuid
                        RETURNING VALUE(r_result) TYPE lcl_consistency=>tt_contract_result.
ENDCLASS.


CLASS lhc_ServiceContract IMPLEMENTATION.

  METHOD get_global_authorizations.
    CLEAR result.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContract FIELDS ( LifecycleStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(contracts).

    " A released contract cannot be released again; consistency is checked by the action itself
    result = VALUE #( FOR c IN contracts
                      ( %tky            = c-%tky
                        %action-release = COND #( WHEN c-LifecycleStatus = zcl_prc_demo_cons_checker=>co_released
                                                  THEN if_abap_behv=>fc-o-disabled
                                                  ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD adjustViaSelectOptions.
    DATA messages TYPE zcl_prc_run_initiator=>tt_messages.

    DATA(job_name) = |Service Contract Adjustment Run - { cl_abap_context_info=>get_system_date( ) }, |
                  && |{ cl_abap_context_info=>get_system_time( ) } - { cl_abap_context_info=>get_user_technical_name( ) }|.

    " Simulation is a property of the run: the job and its processed objects read it there
    DATA(run_uuid) = zcl_prc_run_initiator=>get_instance( )->schedule_run(
      EXPORTING
        i_selection_json    = keys[ 1 ]-%param-selectoptions
        i_parameters        = VALUE #(
            ( name = zcl_prc_demo_adjust_run_job=>co_parameter-equipment_category value = keys[ 1 ]-%param-EquipmentCategory )
            ( name = zcl_prc_demo_adjust_run_job=>co_parameter-discount_percent   value = keys[ 1 ]-%param-DiscountInPercent )
            ( name = zcl_prc_demo_adjust_run_job=>co_parameter-material           value = keys[ 1 ]-%param-Material ) )
        i_application_name  = zcl_prc_demo_adjust_run_job=>co_application_name
        i_job_name          = job_name
        i_job_template_name = zcl_prc_demo_adjust_run_job=>co_job_template_name
        i_simulation        = keys[ 1 ]-%param-Simulation
      IMPORTING
        e_messages          = messages ).

    " Run rejected (e.g. unknown parameter): show the reasons, no run is created
    IF run_uuid IS INITIAL.
      APPEND VALUE #( %cid = keys[ 1 ]-%cid ) TO failed-servicecontract.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %cid = keys[ 1 ]-%cid
                        %msg = message ) TO reported-servicecontract.
      ENDLOOP.
      RETURN.
    ENDIF.

    APPEND VALUE #( %cid           = keys[ 1 ]-%cid
                    %param-runUUID = run_uuid ) TO result.
  ENDMETHOD.


  METHOD checkConsistency.
    " Transient check now: the user sees the findings and the error status at once.
    " The error status is always written, so the contract is part of the save that starts the check.
    DATA(results) = lcl_consistency=>check( VALUE #( FOR k IN keys ( k-UUID ) ) ).
    lcl_consistency=>set_error_status( i_results = results
                                       i_always  = abap_true ).

    LOOP AT results INTO DATA(check_result).
      LOOP AT to_behv_messages( i_conflicts = check_result-conflicts
                                i_severity  = if_abap_behv_message=>severity-warning ) INTO DATA(finding).
        APPEND VALUE #( %tky-UUID = check_result-uuid %msg = finding ) TO reported-servicecontract.
      ENDLOOP.
      APPEND VALUE #( %tky-UUID = check_result-uuid
                      %msg      = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                               number   = '004'
                                               severity = if_abap_behv_message=>severity-information
                                               v1       = check_result-contract_id ) ) TO reported-servicecontract.
      " The documented check in the Processing Center starts with the save
      APPEND VALUE #( uuid = check_result-uuid id = check_result-contract_id ) TO lcl_buffer=>check_consistency.
    ENDLOOP.

    result = VALUE #( FOR r IN read_result( VALUE #( FOR k IN keys ( k-UUID ) ) ) ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD release.
    DATA(results) = lcl_consistency=>check( VALUE #( FOR k IN keys ( k-UUID ) ) ).
    DATA releases TYPE TABLE FOR UPDATE zr_prc_demo_servicecontract\\ServiceContract.
    DATA checked  TYPE lcl_consistency=>tt_result.

    LOOP AT results INTO DATA(check_result).
      IF check_result-lifecycle_status = zcl_prc_demo_cons_checker=>co_released.
        APPEND VALUE #( %tky-UUID = check_result-uuid ) TO failed-servicecontract.
        APPEND VALUE #( %tky-UUID = check_result-uuid
                        %msg      = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                                 number   = '005'
                                                 severity = if_abap_behv_message=>severity-error
                                                 v1       = check_result-contract_id ) ) TO reported-servicecontract.
        CONTINUE.
      ENDIF.

      IF check_result-conflicts IS INITIAL.
        APPEND VALUE #( UUID = check_result-uuid LifecycleStatus = zcl_prc_demo_cons_checker=>co_released ) TO releases.
        APPEND VALUE #( %tky-UUID = check_result-uuid
                        %msg      = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                                 number   = '002'
                                                 severity = if_abap_behv_message=>severity-success
                                                 v1       = check_result-contract_id ) ) TO reported-servicecontract.
      ELSE.
        " Not released, but no FAILED: the error status and the check are still saved
        LOOP AT to_behv_messages( i_conflicts = check_result-conflicts
                                  i_severity  = if_abap_behv_message=>severity-error ) INTO DATA(finding).
          APPEND VALUE #( %tky-UUID = check_result-uuid %msg = finding ) TO reported-servicecontract.
        ENDLOOP.
        APPEND VALUE #( %tky-UUID = check_result-uuid
                        %msg      = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                                 number   = '003'
                                                 severity = if_abap_behv_message=>severity-error
                                                 v1       = check_result-contract_id ) ) TO reported-servicecontract.
      ENDIF.
      " Release also checks: the documented check in the Processing Center starts with the save
      APPEND VALUE #( uuid = check_result-uuid id = check_result-contract_id ) TO lcl_buffer=>release.
      APPEND check_result TO checked.
    ENDLOOP.

    " Always written, so the contract is part of the save that starts the check
    lcl_consistency=>set_error_status( i_results = checked
                                       i_always  = abap_true ).
    IF releases IS NOT INITIAL.
      " The validation checks again with the save - also for releases via API
      MODIFY ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
        ENTITY ServiceContract UPDATE FIELDS ( LifecycleStatus ) WITH releases.
    ENDIF.

    result = VALUE #( FOR r IN read_result( VALUE #( FOR k IN keys ( k-UUID ) ) ) ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.


  METHOD checkAllConsistency.
    DATA messages TYPE zcl_prc_run_initiator=>tt_messages.

    DATA(job_name) = |Service Contract Consistency Check - { cl_abap_context_info=>get_system_date( ) }, |
                  && |{ cl_abap_context_info=>get_system_time( ) } - { cl_abap_context_info=>get_user_technical_name( ) }|.

    " No selection: the run checks all unreleased contracts
    DATA(run_uuid) = zcl_prc_run_initiator=>get_instance( )->schedule_run(
      EXPORTING
        i_selection_json    = ``
        i_parameters        = VALUE #( )
        i_application_name  = zcl_prc_demo_cons_check_job=>co_application_name
        i_job_name          = job_name
        i_job_template_name = zcl_prc_demo_cons_check_job=>co_job_template_name
      IMPORTING
        e_messages          = messages ).

    IF run_uuid IS INITIAL.
      APPEND VALUE #( %cid = keys[ 1 ]-%cid ) TO failed-servicecontract.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %cid = keys[ 1 ]-%cid
                        %msg = message ) TO reported-servicecontract.
      ENDLOOP.
      RETURN.
    ENDIF.

    APPEND VALUE #( %cid = keys[ 1 ]-%cid
                    %msg = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                        number   = '010'
                                        severity = if_abap_behv_message=>severity-success ) ) TO reported-servicecontract.
    APPEND VALUE #( %cid           = keys[ 1 ]-%cid
                    %param-runUUID = run_uuid ) TO result.
  ENDMETHOD.


  METHOD checkReleasedEquipment.
    " Released or being released: a conflict is an error. Otherwise (authoring) a warning.
    LOOP AT lcl_consistency=>check( VALUE #( FOR k IN keys ( k-UUID ) ) ) INTO DATA(check_result)
         WHERE conflicts IS NOT INITIAL.
      DATA(is_released) = xsdbool( check_result-lifecycle_status = zcl_prc_demo_cons_checker=>co_released ).
      IF is_released = abap_true.
        APPEND VALUE #( %tky-UUID = check_result-uuid ) TO failed-servicecontract.
      ENDIF.
      LOOP AT to_behv_messages( i_conflicts = check_result-conflicts
                                i_severity  = COND #( WHEN is_released = abap_true
                                                      THEN if_abap_behv_message=>severity-error
                                                      ELSE if_abap_behv_message=>severity-warning ) ) INTO DATA(finding).
        APPEND VALUE #( %tky-UUID = check_result-uuid %msg = finding ) TO reported-servicecontract.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD setErrorStatus.
    lcl_consistency=>set_error_status( lcl_consistency=>check( VALUE #( FOR k IN keys ( k-UUID ) ) ) ).
  ENDMETHOD.


  METHOD to_behv_messages.
    LOOP AT zcl_prc_demo_cons_checker=>to_messages( i_conflicts = i_conflicts
                                                    i_severity  = 'E' ) INTO DATA(message).
      APPEND new_message( id       = message-msgid
                          number   = message-msgno
                          severity = i_severity
                          v1       = message-msgv1
                          v2       = message-msgv2
                          v3       = message-msgv3 ) TO r_messages.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_result.
    READ ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContract ALL FIELDS WITH VALUE #( FOR u IN i_keys ( UUID = u ) )
      RESULT r_result.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_ServiceContractItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS checkEquipment FOR VALIDATE ON SAVE
      IMPORTING keys FOR ServiceContractItem~checkEquipment.

    METHODS setContractErrorStatus FOR DETERMINE ON SAVE
      IMPORTING keys FOR ServiceContractItem~setContractErrorStatus.

    "! The contracts of the items
    METHODS contracts_of IMPORTING i_item_uuids       TYPE lcl_consistency=>tt_uuid
                         RETURNING VALUE(r_contracts) TYPE lcl_consistency=>tt_uuid.
ENDCLASS.


CLASS lhc_ServiceContractItem IMPLEMENTATION.

  METHOD checkEquipment.
    READ ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContractItem FIELDS ( ParentUUID ItemNumber ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA(results) = lcl_consistency=>check( contracts_of( VALUE #( FOR k IN keys ( k-UUID ) ) ) ).

    " The message belongs to the item whose equipment conflicts
    LOOP AT items INTO DATA(item).
      DATA(check_result) = VALUE #( results[ uuid = item-ParentUUID ] OPTIONAL ).
      DATA(is_released)  = xsdbool( check_result-lifecycle_status = zcl_prc_demo_cons_checker=>co_released ).
      LOOP AT check_result-conflicts INTO DATA(conflict) WHERE item_number = item-ItemNumber.
        IF is_released = abap_true.
          APPEND VALUE #( %tky = item-%tky ) TO failed-servicecontractitem.
        ENDIF.
        APPEND VALUE #( %tky = item-%tky
                        %msg = new_message( id       = 'ZPRC_DEMO_CONS_CHECK'
                                            number   = '001'
                                            severity = COND #( WHEN is_released = abap_true
                                                               THEN if_abap_behv_message=>severity-error
                                                               ELSE if_abap_behv_message=>severity-warning )
                                            v1       = conflict-item_number
                                            v2       = conflict-equipment
                                            v3       = conflict-contract_id ) ) TO reported-servicecontractitem.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD setContractErrorStatus.
    lcl_consistency=>set_error_status( lcl_consistency=>check( contracts_of( VALUE #( FOR k IN keys ( k-UUID ) ) ) ) ).
  ENDMETHOD.


  METHOD contracts_of.
    READ ENTITIES OF zr_prc_demo_servicecontract IN LOCAL MODE
      ENTITY ServiceContractItem FIELDS ( ParentUUID ) WITH VALUE #( FOR u IN i_item_uuids ( UUID = u ) )
      RESULT DATA(items).
    r_contracts = VALUE #( FOR i IN items ( i-ParentUUID ) ).
    SORT r_contracts BY table_line.
    DELETE ADJACENT DUPLICATES FROM r_contracts COMPARING table_line.
  ENDMETHOD.

ENDCLASS.


"! Additional save: the checks of the actions Check and Release start in the
"! Processing Center - objects are written and bgPF is scheduled with this save
CLASS lsc_ServiceContract DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup       REDEFINITION.
ENDCLASS.


CLASS lsc_ServiceContract IMPLEMENTATION.

  METHOD save_modified.
    " Defensive: only contracts that are part of this save (both actions always write the error status)
    DATA contracts TYPE zcl_prc_demo_cons_chk_trigger=>tt_contract.
    LOOP AT VALUE zcl_prc_demo_cons_chk_trigger=>tt_contract( ( LINES OF lcl_buffer=>check_consistency )
                                                               ( LINES OF lcl_buffer=>release ) ) INTO DATA(contract).
      IF line_exists( update-servicecontract[ KEY id COMPONENTS UUID = contract-uuid ] ).
        APPEND contract TO contracts.
      ENDIF.
    ENDLOOP.

    TRY.
        zcl_prc_demo_cons_chk_trigger=>check( contracts ).
      CATCH cx_bgmc ##NO_HANDLER.
        " bgPF not available: new checks are written and wait for the retry job;
        " open checks are processed again by the retry job when due
    ENDTRY.
  ENDMETHOD.


  METHOD cleanup.
    " End of every save and after ROLLBACK ENTITIES: nothing reaches a later save
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.
