FUNCTION Z_PRC_DEMO_BR_MAINTAIN.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_TESTRUN) TYPE  ABAP_BOOLEAN DEFAULT ABAP_FALSE
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BR_LEG-ORDER_ID OPTIONAL
*"     VALUE(IS_DATA) TYPE  ZPRC_DEMO_S_BR_DATA
*"     VALUE(IS_DATAX) TYPE  ZPRC_DEMO_S_BR_DATAX OPTIONAL
*"  EXPORTING
*"     VALUE(EV_ORDER_ID) TYPE  ZPRC_DEMO_BR_LEG-ORDER_ID
*"  TABLES
*"      RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------
  " BAPI A: creates (IV_ORDER_ID initial) or changes a legacy document.
  " Classic BAPI behaviour: own authority check, messages in RETURN (BAPIRET2),
  " test mode, posting via update task, no COMMIT WORK of its own.
  " IS_DATA-ERROR_MODE provokes the error cases of the demo.
  STATICS sv_last_number TYPE n LENGTH 10.
  DATA lv_msg TYPE bapi_msg.

  CLEAR ev_order_id.
  DATA(lv_create) = xsdbool( iv_order_id IS INITIAL ).

  " Own authority check of the BAPI (like real BAPIs). In the RAP late save
  " it is disabled by the authorization context of the BO.
  AUTHORITY-CHECK OBJECT 'ZPRC_PROC'
    ID 'ZPRCNAME' FIELD 'DEMO_BAPI_RAP'
    ID 'ACTVT'    DUMMY.
  IF sy-subrc <> 0.
    MESSAGE e004(zprc_demo_bapi_rap) INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg ) TO return.
    RETURN.
  ENDIF.

  " Business checks - in the test run and in the posting run.
  " Error mode CE is found by the test run the RAP BO calls before the save
  " (precheck of the action, validation on create / update).
  IF ( lv_create = abap_true OR is_datax-description = abap_true ) AND is_data-description IS INITIAL.
    MESSAGE e001(zprc_demo_bapi_rap) INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg ) TO return.
  ENDIF.
  IF is_data-error_mode = 'CE'.
    MESSAGE e020(zprc_demo_bapi_rap) INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg ) TO return.
  ENDIF.

  IF line_exists( return[ type = 'E' ] ) OR iv_testrun = abap_true.
    RETURN.
  ENDIF.

  " Posting run: provoked errors before the update is registered
  CASE is_data-error_mode.
    WHEN 'SM'.
      MESSAGE e022(zprc_demo_bapi_rap).      " unclean BAPI: MESSAGE instead of RETURN
    WHEN 'SX'.
      MESSAGE x023(zprc_demo_bapi_rap).
    WHEN 'SL'.
      " A foreign object (e.g. a referenced document) is locked by someone else
      MESSAGE e024(zprc_demo_bapi_rap) WITH 'OTHER_USER' INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                      message_v1 = sy-msgv1 ) TO return.
      RETURN.
  ENDCASE.

  " Number assignment (demo: next free number; the BAPI owns the numbering)
  IF lv_create = abap_true.
    " Like a number range: exclusive until the update has written the document
    " (scope 2). Parallel callers (PRC steps) wait - otherwise two of them read
    " the same MAX and get the same number.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = 'ZPRC_DEMO_BR_LEG'
        _scope         = '2'
        _wait          = abap_true
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      MESSAGE e005(zprc_demo_bapi_rap) WITH sy-msgv1 INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                      message_v1 = sy-msgv1 ) TO return.
      RETURN.
    ENDIF.

    SELECT MAX( order_id ) FROM zprc_demo_br_leg INTO @DATA(lv_max).
    DATA(lv_next) = nmax( val1 = CONV i( lv_max ) val2 = CONV i( sv_last_number ) ) + 1.
    sv_last_number = lv_next.
    ev_order_id = sv_last_number.
  ELSE.
    ev_order_id = iv_order_id.
  ENDIF.

  CALL FUNCTION 'Z_PRC_DEMO_BR_POST' IN UPDATE TASK
    EXPORTING
      iv_order_id = ev_order_id
      is_data     = is_data
      is_datax    = is_datax
      iv_create   = lv_create.

  " Posting run: provoked errors after the update is registered
  CASE is_data-error_mode.
    WHEN 'SE'.
      " The caller must roll back - this also discards the registered update
      MESSAGE e021(zprc_demo_bapi_rap) INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg ) TO return.
      CLEAR ev_order_id.
      RETURN.
    WHEN 'SC'.
      COMMIT WORK.                           " forbidden for a BAPI - and in the RAP save phase
  ENDCASE.

  MESSAGE s010(zprc_demo_bapi_rap) WITH ev_order_id INTO lv_msg.
  APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                  message_v1 = sy-msgv1 ) TO return.
ENDFUNCTION.
