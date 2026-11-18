"! Work for the save, collected by the actions. Named like the action that fills it.
"! Only the key - no copy of BO data, it could be outdated by later changes.
"! Cleared by the saver's CLEANUP - after every save and after ROLLBACK ENTITIES.
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_keys TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    "! Orders whose BAPI is called in the save
    CLASS-DATA call_bapi TYPE tt_keys.
    CLASS-METHODS clear.
ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.
  METHOD clear.
    CLEAR call_bapi.
  ENDMETHOD.
ENDCLASS.


CLASS lhc_demoorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DemoOrder RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DemoOrder RESULT result.

    METHODS precheck_callbapi FOR PRECHECK
      IMPORTING keys FOR ACTION DemoOrder~callBapi.

    METHODS callbapi FOR MODIFY
      IMPORTING keys FOR ACTION DemoOrder~callBapi RESULT result.
ENDCLASS.


CLASS lhc_demoorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    " The BO's OWN authorization check belongs here - in the interaction phase,
    " whatever it looks like for your BO (demo: everything allowed).
    " It is NOT a repetition of the BAPI's checks: the BAPI is secondary logic.
    result = VALUE #( %create          = if_abap_behv=>auth-allowed
                      %update          = if_abap_behv=>auth-allowed
                      %delete          = if_abap_behv=>auth-allowed
                      %action-callBapi = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD get_instance_features.
    " The BAPI call is remembered for the save of the SAME request.
    " On a draft that save never comes - so the action works on active instances only.
    result = VALUE #( FOR key IN keys
                      ( %tky             = key-%tky
                        %action-callBapi = COND #( WHEN key-%is_draft = if_abap_behv=>mk-on
                                                   THEN if_abap_behv=>fc-o-disabled
                                                   ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.


  METHOD precheck_callbapi.
    " BAPI test run before the action is executed - interaction phase, so the
    " BAPI's own AUTHORITY-CHECK is allowed (in ABAP Cloud there is no way to
    " disable it in a validation). Errors reject the action: FAILED + transient messages.
    READ ENTITIES OF zr_prc_demo_br_action IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      " BAPI -> released wrapper (C1) -> ABAP Cloud
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_testrun = abap_true
                  i_data    = CORRESPONDING #( order MAPPING FROM ENTITY )
        IMPORTING e_return  = DATA(messages) ).

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( %tky = order-%tky ) TO failed-demoorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message( id       = message-id
                                            number   = message-number
                                            severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                            v1       = message-message_v1
                                            v2       = message-message_v2
                                            v3       = message-message_v3
                                            v4       = message-message_v4 ) ) TO reported-demoorder.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD callbapi.
    " Only orders that passed the precheck arrive here.
    " 1) Transactional changes of the action: immediately via EML
    MODIFY ENTITIES OF zr_prc_demo_br_action IN LOCAL MODE
           ENTITY DemoOrder
           UPDATE FIELDS ( Status )
           WITH VALUE #( FOR k IN keys ( %tky = k-%tky Status = abap_true ) ).

    " 2) The posting run is only remembered: key, no BO data
    LOOP AT keys INTO DATA(key).
      INSERT key-OrderUUID INTO TABLE lcl_buffer=>call_bapi.
    ENDLOOP.

    READ ENTITIES OF zr_prc_demo_br_action IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).
    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).
  ENDMETHOD.

ENDCLASS.


"! Saver: CL_ABAP_BEHAVIOR_SAVER_FAILED allows FAILED and REPORTED in the save sequence,
"! so a BAPI error leads to a clean rollback with a message instead of a dump.
CLASS lsc_zr_prc_demo_br_action DEFINITION INHERITING FROM cl_abap_behavior_saver_failed.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup       REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_demo_br_action IMPLEMENTATION.

  METHOD save_modified.
    CHECK lcl_buffer=>call_bapi IS NOT INITIAL.

    " Current state from the transactional buffer - not a copy from action time
    READ ENTITIES OF zr_prc_demo_br_action IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS
         WITH VALUE #( FOR uuid IN lcl_buffer=>call_bapi ( OrderUUID = uuid ) )
         RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      " The BAPI's own authority checks are disabled automatically in the late save
      " (authorization context NoCheckWhenSaving for disable ( save:late ))
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_data   = CORRESPONDING #( order MAPPING FROM ENTITY )
        IMPORTING e_return = DATA(messages) ).

      IF zcl_prc_demo_br_bapi_util=>has_error( messages ).
        " FAILED -> RAP rolls back the whole LUW, incl. updates the BAPI has registered
        APPEND VALUE #( OrderUUID = order-OrderUUID ) TO failed-demoorder.
        LOOP AT messages INTO DATA(message).
          APPEND VALUE #( OrderUUID = order-OrderUUID
                          %msg      = new_message( id       = message-id
                                                   number   = message-number
                                                   severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                                   v1       = message-message_v1
                                                   v2       = message-message_v2
                                                   v3       = message-message_v3
                                                   v4       = message-message_v4 ) ) TO reported-demoorder.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
    " No COMMIT WORK - RAP commits, or rolls back on FAILED
  ENDMETHOD.


  METHOD cleanup.
    " After every save and after ROLLBACK ENTITIES (BDEF: and cleanup). Not in
    " CLEANUP_FINALIZE: after a failed check the LUW goes on, and a corrected save
    " still needs the BAPI call.
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.
