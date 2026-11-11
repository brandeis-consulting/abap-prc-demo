*"* use this source file for your ABAP unit test classes

"! Shared arrangement of the transition tests: process, processed object and
"! a deterministic demo - no error simulated, no waiting. A test injects
"! SIMULATED_ERROR or INSTALL_REQUIRED again where it needs the other case.
CLASS ltc_transition DEFINITION INHERITING FROM zcl_prc_transition_handlr_test ABSTRACT
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PROTECTED SECTION.
    CONSTANTS co_msgid     TYPE symsgid VALUE 'ZPRC_DEMO_API_EQUI'.
    CONSTANTS co_equipment TYPE zi_prc_processedobject-ExternalProcessedObjectID VALUE 'EQUI001'.

  PRIVATE SECTION.
    METHODS setup.
ENDCLASS.


CLASS ltc_transition IMPLEMENTATION.
  METHOD setup.
    initialize( i_process_class           = zcl_prc_demo_create_equi_proc=>co_class_name
                i_process_name            = zcl_prc_demo_create_equi_proc=>co_process_name
                i_processed_object_ext_id = co_equipment ).

    TEST-INJECTION simulated_error.
      r_result = abap_false.
    END-TEST-INJECTION.
    TEST-INJECTION install_required.
      lv_install_required = abap_false.
    END-TEST-INJECTION.
  ENDMETHOD.
ENDCLASS.


"! START -> CREATE_EQUI: own success and failure message
CLASS ltc_validate DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS success_reports_validation FOR TESTING RAISING zcx_prc_unit_of_work_failed.
    METHODS failure_reports_intent     FOR TESTING.
ENDCLASS.


CLASS ltc_validate IMPLEMENTATION.
  METHOD success_reports_validation.
    DATA(new_state) = perform_transition( zif_prc_process=>co_start ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_create_equi_proc=>co_create_equi
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '002' ).
  ENDMETHOD.

  METHOD failure_reports_intent.
    TEST-INJECTION simulated_error.
      r_result = abap_true.
    END-TEST-INJECTION.

    TRY.
        perform_transition( zif_prc_process=>co_start ).
        cl_abap_unit_assert=>fail( `Transition should have failed` ).
      CATCH zcx_prc_unit_of_work_failed.
        cl_abap_unit_assert=>assert_true( message_handler->has_errors( ) ).
        " Header: the failure message of the transition - the cause stays a detail
        assert_header( i_msgid = co_msgid i_msgty = 'E' i_msgno = '010' ).
        assert_message_exists( i_msgid = co_msgid i_msgty = 'E' i_msgno = '001' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! CREATE_EQUI -> LINK_SERIAL: own success and failure message
CLASS ltc_create_equi DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS success_reports_creation FOR TESTING RAISING zcx_prc_unit_of_work_failed.
    METHODS failure_reports_intent   FOR TESTING.
ENDCLASS.


CLASS ltc_create_equi IMPLEMENTATION.
  METHOD success_reports_creation.
    DATA(new_state) = perform_transition( zcl_prc_demo_create_equi_proc=>co_create_equi ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_create_equi_proc=>co_link_serial
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '004' ).
  ENDMETHOD.

  METHOD failure_reports_intent.
    TEST-INJECTION simulated_error.
      r_result = abap_true.
    END-TEST-INJECTION.

    TRY.
        perform_transition( zcl_prc_demo_create_equi_proc=>co_create_equi ).
        cl_abap_unit_assert=>fail( `Transition should have failed` ).
      CATCH zcx_prc_unit_of_work_failed.
        assert_header( i_msgid = co_msgid i_msgty = 'E' i_msgno = '011' ).
        assert_message_exists( i_msgid = co_msgid i_msgty = 'E' i_msgno = '003' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! LINK_SERIAL -> CHECK_INSTALL: no own failure message
CLASS ltc_link_serial DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS success_reports_link         FOR TESTING RAISING zcx_prc_unit_of_work_failed.
    METHODS failure_header_is_last_error FOR TESTING.
ENDCLASS.


CLASS ltc_link_serial IMPLEMENTATION.
  METHOD success_reports_link.
    DATA(new_state) = perform_transition( zcl_prc_demo_create_equi_proc=>co_link_serial ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_create_equi_proc=>co_check_install
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '006' ).
  ENDMETHOD.

  METHOD failure_header_is_last_error.
    TEST-INJECTION simulated_error.
      r_result = abap_true.
    END-TEST-INJECTION.

    TRY.
        perform_transition( zcl_prc_demo_create_equi_proc=>co_link_serial ).
        cl_abap_unit_assert=>fail( `Transition should have failed` ).
      CATCH zcx_prc_unit_of_work_failed.
        " Without a failure message the last error of the step is the header
        assert_header( i_msgid = co_msgid i_msgty = 'E' i_msgno = '005' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! CHECK_INSTALL -> INSTALL_EQUI | FINISHED: fork, the transition returns the end state
CLASS ltc_check_install DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS install_required     FOR TESTING RAISING zcx_prc_unit_of_work_failed.
    METHODS install_not_required FOR TESTING RAISING zcx_prc_unit_of_work_failed.
ENDCLASS.


CLASS ltc_check_install IMPLEMENTATION.
  METHOD install_required.
    TEST-INJECTION install_required.
      lv_install_required = abap_true.
    END-TEST-INJECTION.

    DATA(new_state) = perform_transition( zcl_prc_demo_create_equi_proc=>co_check_install ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_prc_demo_create_equi_proc=>co_install_equi
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '013' ).
  ENDMETHOD.

  METHOD install_not_required.
    DATA(new_state) = perform_transition( zcl_prc_demo_create_equi_proc=>co_check_install ).

    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_finished
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '012' ).
  ENDMETHOD.
ENDCLASS.


"! INSTALL_EQUI -> FINISHED: no own failure message
CLASS ltc_install_equi DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS success_reports_install      FOR TESTING RAISING zcx_prc_unit_of_work_failed.
    METHODS failure_header_is_last_error FOR TESTING.
ENDCLASS.


CLASS ltc_install_equi IMPLEMENTATION.
  METHOD success_reports_install.
    DATA(new_state) = perform_transition( zcl_prc_demo_create_equi_proc=>co_install_equi ).

    cl_abap_unit_assert=>assert_equals( exp = zif_prc_process=>co_finished
                                        act = new_state ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '008' ).
  ENDMETHOD.

  METHOD failure_header_is_last_error.
    TEST-INJECTION simulated_error.
      r_result = abap_true.
    END-TEST-INJECTION.

    TRY.
        perform_transition( zcl_prc_demo_create_equi_proc=>co_install_equi ).
        cl_abap_unit_assert=>fail( `Transition should have failed` ).
      CATCH zcx_prc_unit_of_work_failed.
        assert_header( i_msgid = co_msgid i_msgty = 'E' i_msgno = '007' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


"! Prefix of the application log: names the equipment in front of every entry
CLASS ltc_message_prefix DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS prefix_names_equipment FOR TESTING.
ENDCLASS.


CLASS ltc_message_prefix IMPLEMENTATION.
  METHOD prefix_names_equipment.
    DATA(prefix) = get_message_prefix_for_log( zcl_prc_demo_create_equi_proc=>co_create_equi ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE symsg( msgty = 'I' msgid = co_msgid msgno = '009' msgv1 = co_equipment )
        act = prefix ).
  ENDMETHOD.
ENDCLASS.


"! One path through the graph: the end state of a step is the start state of
"! the next one. Not an integration test of the engine - no persistence.
CLASS ltc_path DEFINITION INHERITING FROM ltc_transition FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS path_without_install FOR TESTING RAISING zcx_prc_unit_of_work_failed.
ENDCLASS.


CLASS ltc_path IMPLEMENTATION.
  METHOD path_without_install.
    DATA states TYPE STANDARD TABLE OF zif_prc_process=>ty_state WITH EMPTY KEY.

    DATA(state) = zif_prc_process=>co_start.
    WHILE state <> zif_prc_process=>co_finished AND lines( states ) < 10.
      APPEND state TO states.
      state = perform_transition( state ).
    ENDWHILE.

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE string_table( ( `START` ) ( `CREATE_EQUI` ) ( `LINK_SERIAL` ) ( `CHECK_INSTALL` ) )
        act = VALUE string_table( FOR s IN states ( CONV #( s ) ) ) ).
    assert_header( i_msgid = co_msgid i_msgty = 'S' i_msgno = '012' ).
  ENDMETHOD.
ENDCLASS.
