"! The decision of the trigger: process open checks again, create new ones otherwise
CLASS ltc_plan DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CONSTANTS: c1 TYPE sysuuid_x16 VALUE '000000000000000000000000000000C1',
               c2 TYPE sysuuid_x16 VALUE '000000000000000000000000000000C2',
               p1 TYPE sysuuid_x16 VALUE '000000000000000000000000000000A1',
               p2 TYPE sysuuid_x16 VALUE '000000000000000000000000000000A2'.

    METHODS no_open_check_creates      FOR TESTING.
    METHODS open_check_is_checked_again FOR TESTING.
    METHODS all_open_checks_again      FOR TESTING.
    METHODS mixed_contracts            FOR TESTING.
    METHODS contract_once              FOR TESTING.
ENDCLASS.


CLASS ltc_plan IMPLEMENTATION.

  METHOD no_open_check_creates.
    " The last check was green (or there was none): a new check
    DATA(plan) = zcl_prc_demo_cons_chk_trigger=>plan( i_contracts   = VALUE #( ( uuid = c1 id = 'C1' ) )
                                                      i_open_checks = VALUE #( ) ).

    cl_abap_unit_assert=>assert_initial( plan-check_again ).
    cl_abap_unit_assert=>assert_equals(
        act = plan-create
        exp = VALUE zcl_prc_processing_api=>tt_create_processed_objects(
                  ( processName         = zcl_prc_demo_cons_check_proc=>co_process_name
                    factoryClassName    = zcl_prc_demo_cons_check_proc=>co_class_name
                    processedObject     = 'C1'
                    processedObjectUUID = c1 ) ) ).
  ENDMETHOD.

  METHOD open_check_is_checked_again.
    " A red check: processed again, no new object
    DATA(plan) = zcl_prc_demo_cons_chk_trigger=>plan( i_contracts   = VALUE #( ( uuid = c1 id = 'C1' ) )
                                                      i_open_checks = VALUE #( ( uuid = p1 contract_uuid = c1 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = plan-check_again exp = VALUE zcl_prc_demo_cons_chk_trigger=>tt_uuid( ( p1 ) ) ).
    cl_abap_unit_assert=>assert_initial( plan-create ).
  ENDMETHOD.

  METHOD all_open_checks_again.
    " Several red checks of one contract (e.g. from runs): all of them are processed again
    DATA(plan) = zcl_prc_demo_cons_chk_trigger=>plan( i_contracts   = VALUE #( ( uuid = c1 id = 'C1' ) )
                                                      i_open_checks = VALUE #( ( uuid = p1 contract_uuid = c1 )
                                                                               ( uuid = p2 contract_uuid = c1 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = plan-check_again exp = VALUE zcl_prc_demo_cons_chk_trigger=>tt_uuid( ( p1 ) ( p2 ) ) ).
    cl_abap_unit_assert=>assert_initial( plan-create ).
  ENDMETHOD.

  METHOD mixed_contracts.
    " C1 has an open check, C2 has none
    DATA(plan) = zcl_prc_demo_cons_chk_trigger=>plan( i_contracts   = VALUE #( ( uuid = c1 id = 'C1' ) ( uuid = c2 id = 'C2' ) )
                                                      i_open_checks = VALUE #( ( uuid = p1 contract_uuid = c1 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = plan-check_again exp = VALUE zcl_prc_demo_cons_chk_trigger=>tt_uuid( ( p1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( plan-create ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = plan-create[ 1 ]-processedObjectUUID exp = c2 ).
  ENDMETHOD.

  METHOD contract_once.
    " Check and Release of the same contract in one LUW: one new check only
    DATA(plan) = zcl_prc_demo_cons_chk_trigger=>plan( i_contracts   = VALUE #( ( uuid = c1 id = 'C1' ) ( uuid = c1 id = 'C1' ) )
                                                      i_open_checks = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( plan-create ) exp = 1 ).
  ENDMETHOD.

ENDCLASS.
