"! The rule against database test doubles: contract C1 is checked, C2 is released
"! with EQ1 and EQ2, C3 is not released and has EQ3
CLASS ltc_find_conflicts DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CONSTANTS: c1 TYPE sysuuid_x16 VALUE '000000000000000000000000000000C1',
               c2 TYPE sysuuid_x16 VALUE '000000000000000000000000000000C2',
               c3 TYPE sysuuid_x16 VALUE '000000000000000000000000000000C3'.

    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS released_equipment_conflicts FOR TESTING.
    METHODS unreleased_contract_ignored  FOR TESTING.
    METHODS own_contract_ignored         FOR TESTING.
    METHODS without_equipment_skipped    FOR TESTING.
    METHODS conflict_as_message          FOR TESTING.
ENDCLASS.


CLASS ltc_find_conflicts IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZPRC_DEMO_SRVCTR' ) ( 'ZPRC_DEMO_SC_ITM' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    DATA contracts TYPE STANDARD TABLE OF zprc_demo_srvctr WITH EMPTY KEY.
    DATA items     TYPE STANDARD TABLE OF zprc_demo_sc_itm WITH EMPTY KEY.
    contracts = VALUE #( ( uuid = c1 service_contract_id = 'C1' lifecycle_status = 'D' )
                         ( uuid = c2 service_contract_id = 'C2' lifecycle_status = 'D' )
                         ( uuid = c3 service_contract_id = 'C3' lifecycle_status = 'A' ) ).
    items = VALUE #( ( uuid = '000000000000000000000000000000A1' parent_uuid = c1 item_number = '000010' equipment_id = 'EQ1' )
                     ( uuid = '000000000000000000000000000000A2' parent_uuid = c2 item_number = '000010' equipment_id = 'EQ1' )
                     ( uuid = '000000000000000000000000000000A3' parent_uuid = c2 item_number = '000020' equipment_id = 'EQ2' )
                     ( uuid = '000000000000000000000000000000A4' parent_uuid = c3 item_number = '000010' equipment_id = 'EQ3' ) ).
    environment->insert_test_data( contracts ).
    environment->insert_test_data( items ).
  ENDMETHOD.

  METHOD released_equipment_conflicts.
    cl_abap_unit_assert=>assert_equals(
        act = zcl_prc_demo_cons_checker=>find_conflicts(
                  i_contract_uuid = c3
                  i_items         = VALUE #( ( item_number = '000010' equipment = 'EQ2' )
                                             ( item_number = '000020' equipment = 'EQ1' )
                                             ( item_number = '000030' equipment = 'EQ9' ) ) )
        " EQ1 is released twice (C1 and C2), EQ2 once (C2), EQ9 nowhere
        exp = VALUE zcl_prc_demo_cons_checker=>tt_conflict(
                  ( item_number = '000010' equipment = 'EQ2' contract_id = 'C2' )
                  ( item_number = '000020' equipment = 'EQ1' contract_id = 'C1' )
                  ( item_number = '000020' equipment = 'EQ1' contract_id = 'C2' ) ) ).
  ENDMETHOD.

  METHOD unreleased_contract_ignored.
    " EQ3 is in C3 only, which is not released
    cl_abap_unit_assert=>assert_initial( zcl_prc_demo_cons_checker=>find_conflicts(
        i_contract_uuid = c1
        i_items         = VALUE #( ( item_number = '000010' equipment = 'EQ3' ) ) ) ).
  ENDMETHOD.

  METHOD own_contract_ignored.
    " C2 itself is released with EQ2 - that is no conflict with itself
    cl_abap_unit_assert=>assert_initial( zcl_prc_demo_cons_checker=>find_conflicts(
        i_contract_uuid = c2
        i_items         = VALUE #( ( item_number = '000020' equipment = 'EQ2' ) ) ) ).
  ENDMETHOD.

  METHOD without_equipment_skipped.
    cl_abap_unit_assert=>assert_initial( zcl_prc_demo_cons_checker=>find_conflicts(
        i_contract_uuid = c3
        i_items         = VALUE #( ( item_number = '000010' ) ) ) ).
  ENDMETHOD.

  METHOD conflict_as_message.
    DATA(messages) = zcl_prc_demo_cons_checker=>to_messages(
        i_conflicts = VALUE #( ( item_number = '000010' equipment = 'EQ2' contract_id = 'C2' ) )
        i_severity  = 'W' ).

    cl_abap_unit_assert=>assert_equals(
        act = messages
        exp = VALUE zcl_prc_demo_cons_checker=>tt_message(
                  ( msgty = 'W' msgid = 'ZPRC_DEMO_CONS_CHECK' msgno = '001' msgv1 = '000010' msgv2 = 'EQ2' msgv3 = 'C2' ) ) ).
  ENDMETHOD.

ENDCLASS.
