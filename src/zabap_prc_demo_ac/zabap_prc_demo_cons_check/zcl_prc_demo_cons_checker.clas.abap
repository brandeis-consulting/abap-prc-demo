"! <p class="shorttext synchronized">Demo: Consistency rule of a service contract</p>
"!
"! The one rule of the consistency check demo: an equipment must not be in two
"! released service contracts. A contract can become inconsistent without
"! being changed - when another contract with the same equipment is released.
"!
"! Read only, no RAP, no Processing Center: the same rule is used by
"! <ul>
"! <li>the validation of the service contract (warning while not released,
"!     error once released),</li>
"! <li>the actions Check and Release of the service contract (transient check),</li>
"! <li>the transition of ZCL_PRC_DEMO_CONS_CHECK_PROC (findings).</li>
"! </ul>
"! The items of the checked contract are handed in (they may be in the
"! transactional buffer); the other contracts are read from the database.
CLASS zcl_prc_demo_cons_checker DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Lifecycle status of a released contract (domain ZPRC_DEMO_LIFECYCLE_STATUS)
    CONSTANTS co_released TYPE zprc_demo_lifecycle_status VALUE 'D'.

    TYPES: BEGIN OF ty_item,
             item_number TYPE zprc_demo_sc_itm-item_number,
             equipment   TYPE zprc_demo_sc_itm-equipment_id,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    " An item whose equipment is in another released contract
    TYPES: BEGIN OF ty_conflict,
             item_number TYPE zprc_demo_sc_itm-item_number,
             equipment   TYPE zprc_demo_sc_itm-equipment_id,
             contract_id TYPE zprc_demo_srvctr-service_contract_id,
           END OF ty_conflict,
           tt_conflict TYPE STANDARD TABLE OF ty_conflict WITH EMPTY KEY.

    TYPES tt_message TYPE STANDARD TABLE OF symsg WITH EMPTY KEY.

    "! Items whose equipment is in another released contract - one entry per
    "! item and other contract, sorted by item number.
    "!
    "! @parameter i_contract_uuid | Checked contract; never a conflict with itself.
    "! @parameter i_items         | Items of the checked contract; items without equipment are skipped.
    "! @parameter r_conflicts     | Conflicts; empty if the contract is consistent.
    CLASS-METHODS find_conflicts IMPORTING i_contract_uuid    TYPE sysuuid_x16
                                           i_items            TYPE tt_item
                                 RETURNING VALUE(r_conflicts) TYPE tt_conflict.

    "! The conflicts as messages ZPRC_DEMO_CONS_CHECK/001.
    "!
    "! @parameter i_conflicts | Conflicts of FIND_CONFLICTS.
    "! @parameter i_severity  | Message type: E for findings and errors, W for warnings.
    "! @parameter r_messages  | One message per conflict.
    CLASS-METHODS to_messages IMPORTING i_conflicts       TYPE tt_conflict
                                        i_severity        TYPE symsgty
                              RETURNING VALUE(r_messages) TYPE tt_message.
ENDCLASS.


CLASS zcl_prc_demo_cons_checker IMPLEMENTATION.

  METHOD find_conflicts.
    DATA equipments TYPE RANGE OF zprc_demo_sc_itm-equipment_id.
    equipments = VALUE #( FOR i IN i_items WHERE ( equipment IS NOT INITIAL )
                          ( sign = 'I' option = 'EQ' low = i-equipment ) ).
    IF equipments IS INITIAL.
      RETURN.
    ENDIF.
    SORT equipments BY low.
    DELETE ADJACENT DUPLICATES FROM equipments COMPARING low.

    " The equipments in released contracts other than the checked one
    SELECT item~equipment_id AS equipment, contract~service_contract_id AS contract_id
      FROM zprc_demo_sc_itm AS item
             INNER JOIN zprc_demo_srvctr AS contract ON contract~uuid = item~parent_uuid
      WHERE contract~lifecycle_status =  @co_released
        AND contract~uuid             <> @i_contract_uuid
        AND item~equipment_id         IN @equipments
      INTO TABLE @DATA(released).

    LOOP AT i_items INTO DATA(item) WHERE equipment IS NOT INITIAL.
      LOOP AT released INTO DATA(other) WHERE equipment = item-equipment.
        APPEND VALUE #( item_number = item-item_number
                        equipment   = item-equipment
                        contract_id = other-contract_id ) TO r_conflicts.
      ENDLOOP.
    ENDLOOP.
    SORT r_conflicts BY item_number contract_id.
    DELETE ADJACENT DUPLICATES FROM r_conflicts COMPARING item_number contract_id.
  ENDMETHOD.


  METHOD to_messages.
    LOOP AT i_conflicts INTO DATA(conflict).
      MESSAGE ID 'ZPRC_DEMO_CONS_CHECK' TYPE i_severity NUMBER '001'
              WITH conflict-item_number conflict-equipment conflict-contract_id
              INTO DATA(text) ##NEEDED.
      APPEND VALUE #( msgty = sy-msgty msgid = sy-msgid msgno = sy-msgno
                      msgv1 = sy-msgv1 msgv2 = sy-msgv2 msgv3 = sy-msgv3 msgv4 = sy-msgv4 ) TO r_messages.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
