CLASS lcl_root DEFINITION INHERITING FROM zcl_prc_transition_handlr_base ABSTRACT.
  PROTECTED SECTION.
    METHODS get_message_prefix_for_log REDEFINITION.

    "! Demo: simulates the work of a step and decides whether it fails.
    "! Test seam SIMULATED_ERROR makes the decision deterministic in unit tests.
    METHODS is_error_simulated RETURNING VALUE(r_result) TYPE abap_bool.
ENDCLASS.


CLASS lcl_root IMPLEMENTATION.

  METHOD get_message_prefix_for_log.
    MESSAGE i009(zprc_demo_api_equi) WITH i_processed_object_ext_id INTO DATA(message_prefix) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

  METHOD is_error_simulated.
    TEST-SEAM simulated_error.
      WAIT UP TO 1 SECONDS.
      " Demo: the last digit of the current second decides whether an error is simulated
      r_result = xsdbool( CONV i( cl_abap_context_info=>get_system_time( ) ) MOD 10 = 1 ).
    END-TEST-SEAM.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_validate DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS get_success_message REDEFINITION.
    METHODS get_failure_message REDEFINITION.
    METHODS perform_transition REDEFINITION.
ENDCLASS.


CLASS lcl_validate IMPLEMENTATION.
  METHOD perform_transition.
    IF is_error_simulated( ).
      MESSAGE e001(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_failure_message.
    MESSAGE e010(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

  METHOD get_success_message.
    MESSAGE s002(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.


CLASS lcl_create_equi DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS get_failure_message REDEFINITION.
    METHODS perform_transition REDEFINITION.
    METHODS get_success_message REDEFINITION.
ENDCLASS.


CLASS lcl_create_equi IMPLEMENTATION.
  METHOD perform_transition.
    IF is_error_simulated( ).
      MESSAGE e003(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_failure_message.
    MESSAGE e011(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

  METHOD get_success_message.
    MESSAGE s004(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.


CLASS lcl_link_serial DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS get_success_message REDEFINITION.
    METHODS perform_transition REDEFINITION.
ENDCLASS.


CLASS lcl_link_serial IMPLEMENTATION.
  METHOD perform_transition.
    IF is_error_simulated( ).
      MESSAGE e005(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_success_message.
    MESSAGE s006(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.


CLASS lcl_check_install DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS get_success_message REDEFINITION.
    METHODS perform_transition REDEFINITION.
    DATA: mv_next_state TYPE zif_prc_process=>ty_state.
ENDCLASS.

CLASS lcl_check_install IMPLEMENTATION.
  METHOD perform_transition.
    DATA lv_install_required TYPE abap_bool.

    TEST-SEAM install_required.
      WAIT UP TO 1 SECONDS.
      " Demo: even/odd second decides the branch (fork)
      lv_install_required = xsdbool( CONV i( cl_abap_context_info=>get_system_time( ) ) MOD 2 <> 0 ).
    END-TEST-SEAM.

    IF lv_install_required = abap_true.
      r_new_state = zcl_prc_demo_create_equi_proc=>co_install_equi.
    ELSE.
      r_new_state = zif_prc_process=>co_finished.
    ENDIF.
    mv_next_state = r_new_state.
  ENDMETHOD.

  METHOD get_success_message.
    IF mv_next_state = zcl_prc_demo_create_equi_proc=>co_install_equi.
      MESSAGE s013(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    ELSE.
      MESSAGE s012(zprc_demo_api_equi) INTO lv_dummy_message ##NEEDED.
    ENDIF.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.



CLASS lcl_install_equi DEFINITION INHERITING FROM lcl_root.
  PROTECTED SECTION.
    METHODS perform_transition REDEFINITION.
    METHODS get_success_message REDEFINITION.
ENDCLASS.


CLASS lcl_install_equi IMPLEMENTATION.
  METHOD perform_transition.
    IF is_error_simulated( ).
      MESSAGE e007(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
      get_message_handler( )->add_message_from_sy( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_success_message.
    MESSAGE s008(zprc_demo_api_equi) INTO DATA(lv_dummy_message) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.
ENDCLASS.
