CLASS lhc_legacyorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR LegacyOrder RESULT result.

    METHODS checkwithbapi FOR VALIDATE ON SAVE
      IMPORTING keys FOR LegacyOrder~checkWithBapi.
ENDCLASS.


CLASS lhc_legacyorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    " The BO's OWN authorization check belongs here - in the interaction phase,
    " whatever it looks like for your BO (demo: everything allowed).
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD checkwithbapi.
    " BAPI test run on the final state - state messages stay with the draft.
    " Validations run in the early save, where AUTHORITY-CHECK is not allowed.
    " Standard ABAP can disable the BAPI's own check explicitly - ABAP Cloud cannot,
    " and save:early is not supported for managed BOs.
    READ ENTITIES OF zr_prc_demo_br_persist IN LOCAL MODE
         ENTITY LegacyOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'CHECK_BAPI' ) TO reported-legacyorder.

      AUTHORITY-CHECK DISABLE BEGIN CONTEXT zr_prc_demo_br_persist~NoCheckWhenSaving.
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_testrun  = abap_true
                  i_order_id = order-OrderID       " initial = create (number not assigned yet)
                  i_data     = CORRESPONDING #( order MAPPING FROM ENTITY )
                  i_datax    = VALUE #( description = abap_true error_mode = abap_true )
        IMPORTING e_return   = DATA(messages) ).
      AUTHORITY-CHECK DISABLE END.

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( %tky = order-%tky ) TO failed-legacyorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %tky        = order-%tky
                        %state_area = 'CHECK_BAPI'
                        %msg        = new_message( id       = message-id
                                                   number   = message-number
                                                   severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                                   v1       = message-message_v1
                                                   v2       = message-message_v2
                                                   v3       = message-message_v3
                                                   v4       = message-message_v4 ) ) TO reported-legacyorder.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! The BAPI is the persistence. CL_ABAP_BEHAVIOR_SAVER_FAILED allows FAILED and
"! REPORTED in ADJUST_NUMBERS and SAVE_MODIFIED: clean rollback with message.
CLASS lsc_zr_prc_demo_br_persist DEFINITION INHERITING FROM cl_abap_behavior_saver_failed.
  PROTECTED SECTION.
    METHODS adjust_numbers REDEFINITION.
    METHODS save_modified  REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_demo_br_persist IMPLEMENTATION.

  METHOD adjust_numbers.
    " The BAPI assigns the number: the create BAPI is called here (after the point
    " of no return) and returns the final key. MAPPED holds the %pid of new instances.
    " The BAPI's authority checks are disabled automatically (save:late).
    CHECK mapped-legacyorder IS NOT INITIAL.

    READ ENTITIES OF zr_prc_demo_br_persist IN LOCAL MODE
         ENTITY LegacyOrder ALL FIELDS
         WITH VALUE #( FOR map IN mapped-legacyorder ( %pid = map-%pid %key = map-%tmp ) )
         RESULT DATA(orders).

    LOOP AT mapped-legacyorder ASSIGNING FIELD-SYMBOL(<map>).
      DATA(order) = orders[ KEY pid COMPONENTS %pid = <map>-%pid ].
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_data     = CORRESPONDING #( order MAPPING FROM ENTITY )
        IMPORTING e_order_id = <map>-OrderID
                  e_return   = DATA(messages) ).

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( %pid = <map>-%pid ) TO failed-legacyorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %pid = <map>-%pid
                        %msg = new_message( id       = message-id
                                            number   = message-number
                                            severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                            v1       = message-message_v1
                                            v2       = message-message_v2
                                            v3       = message-message_v3
                                            v4       = message-message_v4 ) ) TO reported-legacyorder.
      ENDLOOP.
    ENDLOOP.
    " Posting happens via update task with the RAP commit
  ENDMETHOD.


  METHOD save_modified.
    " Creates were posted in ADJUST_NUMBERS - only updates remain
    LOOP AT update-legacyorder INTO DATA(change).
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_order_id = change-OrderID
                  i_data     = CORRESPONDING #( change MAPPING FROM ENTITY )
                  " X structure from %control via the BDEF mapping
                  i_datax    = CORRESPONDING #( change MAPPING FROM ENTITY USING CONTROL )
        IMPORTING e_return   = DATA(messages) ).

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( OrderID = change-OrderID ) TO failed-legacyorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( OrderID = change-OrderID
                        %msg    = new_message( id       = message-id
                                               number   = message-number
                                               severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                               v1       = message-message_v1
                                               v2       = message-message_v2
                                               v3       = message-message_v3
                                               v4       = message-message_v4 ) ) TO reported-legacyorder.
      ENDLOOP.
    ENDLOOP.
    " No COMMIT WORK - RAP commits, the update task posts
  ENDMETHOD.

ENDCLASS.
