"! START -> START | FINISHED: checks the contract with ZCL_PRC_DEMO_CONS_CHECKER,
"! collects every finding without failing, marks the contract and decides the
"! end state.
CLASS lcl_check DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition         REDEFINITION.
    METHODS get_success_message        REDEFINITION.
    METHODS get_message_prefix_for_log REDEFINITION.
ENDCLASS.


CLASS lcl_check IMPLEMENTATION.

  METHOD perform_transition.
    DATA(handler) = get_message_handler( ).

    READ ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContract
        FIELDS ( ServiceContractID ) WITH VALUE #( ( UUID = i_processed_object_ext_uuid ) )
        RESULT DATA(contracts)
      ENTITY ServiceContract BY \_ServiceContractItem
        FIELDS ( ItemNumber EquipmentId ) WITH VALUE #( ( UUID = i_processed_object_ext_uuid ) )
        RESULT DATA(items).

    IF contracts IS INITIAL.
      " Nothing to check: a real failure, not a finding
      MESSAGE e009(zprc_demo_cons_check) WITH i_processed_object_ext_id INTO DATA(dummy) ##NEEDED.
      handler->add_message_from_sy( ).
    ENDIF.

    " Every conflict is a finding: recorded, the check goes on and reports all of them
    DATA(conflicts) = zcl_prc_demo_cons_checker=>find_conflicts(
                          i_contract_uuid = i_processed_object_ext_uuid
                          i_items         = VALUE #( FOR i IN items ( item_number = i-ItemNumber
                                                                      equipment   = i-EquipmentId ) ) ).
    LOOP AT zcl_prc_demo_cons_checker=>to_messages( i_conflicts = conflicts
                                                    i_severity  = 'E' ) INTO DATA(finding).
      MESSAGE ID finding-msgid TYPE finding-msgty NUMBER finding-msgno
              WITH finding-msgv1 finding-msgv2 finding-msgv3 finding-msgv4 INTO dummy.
      handler->add_message_from_sy( i_fail_step = abap_false ).
    ENDLOOP.

    " Findings are errors that did not fail the step
    DATA(has_findings) = handler->has_errors( ).
    IF has_findings = abap_true.
      " Summary as the last finding: the engine shows the last error as step header
      DATA(count) = lines( conflicts ).
      MESSAGE e007(zprc_demo_cons_check) WITH contracts[ 1 ]-ServiceContractID count INTO dummy.
      handler->add_message_from_sy( i_fail_step = abap_false ).
    ENDIF.

    " The result belongs to the contract - committed with the step, also with findings
    MODIFY ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContract
        UPDATE FIELDS ( ErrorStatus )
        WITH VALUE #( ( UUID        = i_processed_object_ext_uuid
                        ErrorStatus = COND #( WHEN has_findings = abap_true
                                              THEN zcl_prc_demo_cons_check_proc=>error_status-contains_error
                                              ELSE zcl_prc_demo_cons_check_proc=>error_status-no_error ) ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).
    " Not a finding: if the contract cannot be marked, the step fails
    handler->add_eml_modify_result( i_failed   = failed
                                    i_reported = reported ).

    " Two transitions start in START: the end state has to be proposed
    r_new_state = COND #( WHEN has_findings = abap_true
                          THEN i_start_state
                          ELSE zif_prc_process=>co_finished ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s006(zprc_demo_cons_check) WITH i_processed_object_ext_id INTO DATA(dummy) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.


  METHOD get_message_prefix_for_log.
    MESSAGE i008(zprc_demo_cons_check) WITH i_processed_object_ext_id INTO DATA(dummy) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
