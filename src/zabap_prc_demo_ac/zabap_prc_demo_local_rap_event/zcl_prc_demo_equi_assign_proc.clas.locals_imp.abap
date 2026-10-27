CLASS lcl_root DEFINITION INHERITING FROM zcl_prc_transition_handlr_base ABSTRACT.
  PROTECTED SECTION.
    METHODS get_message_prefix_for_log REDEFINITION.
ENDCLASS.


CLASS lcl_root IMPLEMENTATION.

  METHOD get_message_prefix_for_log.
    " Equipment &1: (own message class - the scenario does not depend on Create Equipment)
    MESSAGE i005(zprc_demo_event_equi) WITH i_processed_object_ext_id INTO DATA(message_prefix) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.


"! Assigns the new equipment to the next free item: the first item without equipment
"! of a service contract that is open (A) or in process (B), by contract and item number.
"! The update goes through the service contract BO, so its lock applies: if the contract
"! is locked, the step fails and the retry job assigns the equipment later.
CLASS lcl_assign_to_srv_ctr DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS get_success_message REDEFINITION.
    METHODS get_failure_message REDEFINITION.
    METHODS perform_transition REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS: BEGIN OF co_lifecycle_status,
                 open       TYPE zprc_demo_lifecycle_status VALUE 'A',
                 in_process TYPE zprc_demo_lifecycle_status VALUE 'B',
               END OF co_lifecycle_status.

    DATA mv_equipment_id TYPE string.
    DATA mv_contract_id  TYPE string.
    DATA mv_item_number  TYPE string.
ENDCLASS.


CLASS lcl_assign_to_srv_ctr IMPLEMENTATION.
  METHOD perform_transition.
    mv_equipment_id = i_processed_object_ext_id.

    SELECT FROM zr_prc_demo_servicecontractitm AS item
             INNER JOIN zr_prc_demo_servicecontract AS contract ON contract~UUID = item~ParentUUID
           FIELDS item~UUID, item~ItemNumber, contract~ServiceContractID
           WHERE item~EquipmentId         = @space
             AND contract~LifecycleStatus IN ( @co_lifecycle_status-open, @co_lifecycle_status-in_process )
           ORDER BY contract~ServiceContractID, item~ItemNumber
           INTO TABLE @DATA(lt_free_items)
           UP TO 1 ROWS.

    IF lt_free_items IS INITIAL.
      " No free item in an open or in-process service contract
      MESSAGE e003(zprc_demo_event_equi) INTO DATA(lv_dummy_message) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.

    DATA(ls_free_item) = lt_free_items[ 1 ].
    mv_contract_id = |{ ls_free_item-ServiceContractID ALPHA = OUT }|.
    mv_item_number = |{ ls_free_item-ItemNumber ALPHA = OUT }|.

    MODIFY ENTITIES OF zr_prc_demo_servicecontract
           ENTITY ServiceContractItem
           UPDATE FIELDS ( EquipmentId )
           WITH VALUE #( ( UUID = ls_free_item-UUID EquipmentId = i_processed_object_ext_id ) )
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported).

    IF line_exists( ls_failed-servicecontractitem[ %fail-cause = if_abap_behv=>cause-locked ] ).
      " Service contract &1 is locked - the assignment will be retried
      MESSAGE e004(zprc_demo_event_equi) WITH mv_contract_id INTO lv_dummy_message ##NEEDED.
      get_message_handler( )->add_message_from_sy( i_fail_on_error_message = abap_false ).
    ENDIF.
    " FAILED (e.g. the lock) fails the step; the retry job tries again later
    get_message_handler( )->add_eml_modify_result( i_failed   = ls_failed
                                                   i_reported = ls_reported ).
  ENDMETHOD.

  METHOD get_failure_message.
    " Equipment &1 could not be assigned to a service contract
    MESSAGE e002(zprc_demo_event_equi) WITH mv_equipment_id INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

  METHOD get_success_message.
    " Equipment &1 assigned to service contract &2, item &3
    MESSAGE s001(zprc_demo_event_equi) WITH mv_equipment_id mv_contract_id mv_item_number
            INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.
