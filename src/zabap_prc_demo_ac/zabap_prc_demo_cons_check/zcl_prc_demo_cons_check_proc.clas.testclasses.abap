"! Shared arrangement: contract RELEASED is on the database (test double) and
"! released with equipment EQ1. The checked contract is created in the
"! transactional buffer (never saved) and checked like one step of the engine.
"! TEARDOWN discards it.
CLASS ltc_check DEFINITION INHERITING FROM zcl_prc_transition_handlr_test ABSTRACT
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PROTECTED SECTION.
    CONSTANTS co_msgid    TYPE symsgid VALUE 'ZPRC_DEMO_CONS_CHECK'.
    CONSTANTS co_contract TYPE zprc_demo_srvctr-service_contract_id VALUE 'SC-TEST'.

    "! UUID of the contract created by GIVEN_CONTRACT
    DATA contract_uuid TYPE sysuuid_x16.

    "! Creates the checked contract with one item per equipment and initializes the test base
    METHODS given_contract IMPORTING i_equipments TYPE string_table.

    "! Error status of the checked contract in the buffer
    METHODS error_status RETURNING VALUE(r_status) TYPE zprc_demo_error_status.

  PRIVATE SECTION.
    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
ENDCLASS.


CLASS ltc_check IMPLEMENTATION.

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
    contracts = VALUE #( ( uuid                = '000000000000000000000000000000D1'
                           service_contract_id = 'RELEASED'
                           lifecycle_status    = zcl_prc_demo_cons_checker=>co_released ) ).
    items = VALUE #( ( uuid         = '000000000000000000000000000000E1'
                       parent_uuid  = '000000000000000000000000000000D1'
                       item_number  = '000010'
                       equipment_id = 'EQ1' ) ).
    environment->insert_test_data( contracts ).
    environment->insert_test_data( items ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.


  METHOD given_contract.
    MODIFY ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContract
        CREATE FIELDS ( ServiceContractID Description )
        WITH VALUE #( ( %cid = 'C' ServiceContractID = co_contract Description = 'Consistency check test' ) )
        CREATE BY \_ServiceContractItem
        FIELDS ( ItemNumber EquipmentId )
        WITH VALUE #( ( %cid_ref = 'C'
                        %target  = VALUE #( FOR e IN i_equipments INDEX INTO i
                                            ( %cid        = |I{ i }|
                                              ItemNumber  = i * 10
                                              EquipmentId = e ) ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed).
    cl_abap_unit_assert=>assert_initial( act = failed msg = 'Test contract could not be created' ).
    contract_uuid = mapped-servicecontract[ 1 ]-UUID.

    initialize( i_process_class             = zcl_prc_demo_cons_check_proc=>co_class_name
                i_process_name              = zcl_prc_demo_cons_check_proc=>co_process_name
                i_processed_object_ext_id   = CONV #( co_contract )
                i_processed_object_ext_uuid = contract_uuid
                " The contract exists in the buffer only - nothing to simulate on the database
                i_simulate_save             = abap_false ).
  ENDMETHOD.


  METHOD error_status.
    READ ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContract FIELDS ( ErrorStatus ) WITH VALUE #( ( UUID = contract_uuid ) )
      RESULT DATA(contracts).
    r_status = contracts[ 1 ]-ErrorStatus.
  ENDMETHOD.

ENDCLASS.


"! START -> FINISHED: no equipment of the contract is released elsewhere - marked N
CLASS ltc_consistent DEFINITION INHERITING FROM ltc_check FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS finished_and_marked_n FOR TESTING RAISING zcx_prc_unit_of_work_failed.
ENDCLASS.


CLASS ltc_consistent IMPLEMENTATION.
  METHOD finished_and_marked_n.
    given_contract( VALUE #( ( `EQ2` ) ( `EQ3` ) ) ).

    DATA(new_state) = perform_transition( zif_prc_process=>co_start ).

    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_finished act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '006' ).
    cl_abap_unit_assert=>assert_false( message_handler->has_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_cons_check_proc=>error_status-no_error
                                        act = error_status( ) ).
  ENDMETHOD.
ENDCLASS.


"! START -> START: the equipment is in the released contract - a finding, marked E
CLASS ltc_findings DEFINITION INHERITING FROM ltc_check FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS findings_marked_e FOR TESTING RAISING zcx_prc_unit_of_work_failed.
ENDCLASS.


CLASS ltc_findings IMPLEMENTATION.
  METHOD findings_marked_e.
    " Items 10 and 30 use EQ1, which is in contract RELEASED; item 20 is fine
    given_contract( VALUE #( ( `EQ1` ) ( `EQ2` ) ( `EQ1` ) ) ).

    DATA(new_state) = perform_transition( zif_prc_process=>co_start ).

    " Findings: no exception, back to the start state, the step has not failed
    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_start act = new_state ).
    cl_abap_unit_assert=>assert_false( message_handler->has_failed( ) ).
    cl_abap_unit_assert=>assert_true( message_handler->has_errors( ) ).
    " Both conflicts are reported - the check does not stop at the first one
    DATA(messages) = message_handler->get_messages( ).
    cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = REDUCE i( INIT n = 0 FOR m IN messages WHERE ( msgid = co_msgid AND msgno = '001' ) NEXT n = n + 1 ) ).
    " The summary is the header and counts the findings
    assert_header( i_msgid = co_msgid i_msgty = 'E' i_msgno = '007' ).
    cl_abap_unit_assert=>assert_equals( exp = '2' act = condense( header-msgv2 ) ).
    " The change a failing step would roll back
    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_cons_check_proc=>error_status-contains_error
                                        act = error_status( ) ).
  ENDMETHOD.
ENDCLASS.


"! The demo path: findings, the equipment is replaced, the check finishes
CLASS ltc_correct_and_check_again DEFINITION INHERITING FROM ltc_check FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS finished_after_correction FOR TESTING RAISING zcx_prc_unit_of_work_failed.
ENDCLASS.


CLASS ltc_correct_and_check_again IMPLEMENTATION.
  METHOD finished_after_correction.
    given_contract( VALUE #( ( `EQ1` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_start
                                        act = perform_transition( zif_prc_process=>co_start ) ).

    " The user replaces the equipment
    READ ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContract BY \_ServiceContractItem FIELDS ( UUID ) WITH VALUE #( ( UUID = contract_uuid ) )
      RESULT DATA(items).
    MODIFY ENTITIES OF zr_prc_demo_servicecontract
      ENTITY ServiceContractItem UPDATE FIELDS ( EquipmentId )
      WITH VALUE #( ( UUID = items[ 1 ]-UUID EquipmentId = 'EQ2' ) ).

    " Checked again from START
    DATA(new_state) = perform_transition( zif_prc_process=>co_start ).

    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_finished act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '006' ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_cons_check_proc=>error_status-no_error
                                        act = error_status( ) ).
  ENDMETHOD.
ENDCLASS.


"! A contract that does not exist: a real failure, not a finding
CLASS ltc_not_found DEFINITION INHERITING FROM zcl_prc_transition_handlr_test FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS fails_the_step FOR TESTING.
ENDCLASS.


CLASS ltc_not_found IMPLEMENTATION.
  METHOD fails_the_step.
    initialize( i_process_class             = zcl_prc_demo_cons_check_proc=>co_class_name
                i_process_name              = zcl_prc_demo_cons_check_proc=>co_process_name
                i_processed_object_ext_id   = 'SC-NONE'
                i_processed_object_ext_uuid = '000000000000000000000000000000FF'
                i_simulate_save             = abap_false ).
    TRY.
        perform_transition( zif_prc_process=>co_start ).
        cl_abap_unit_assert=>fail( `A missing contract must fail the step` ).
      CATCH zcx_prc_unit_of_work_failed.
        cl_abap_unit_assert=>assert_true( message_handler->has_failed( ) ).
        assert_header( i_msgid = 'ZPRC_DEMO_CONS_CHECK' i_msgty = 'E' i_msgno = '009' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! Prefix of the application log: names the contract in front of every entry
CLASS ltc_message_prefix DEFINITION INHERITING FROM zcl_prc_transition_handlr_test FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS prefix_names_contract FOR TESTING.
ENDCLASS.


CLASS ltc_message_prefix IMPLEMENTATION.
  METHOD prefix_names_contract.
    initialize( i_process_class           = zcl_prc_demo_cons_check_proc=>co_class_name
                i_process_name            = zcl_prc_demo_cons_check_proc=>co_process_name
                i_processed_object_ext_id = 'SC-1' ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE symsg( msgty = 'I' msgid = 'ZPRC_DEMO_CONS_CHECK' msgno = '008' msgv1 = 'SC-1' )
        act = get_message_prefix_for_log( zif_prc_process=>co_start ) ).
  ENDMETHOD.
ENDCLASS.
