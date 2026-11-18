FUNCTION Z_PRC_DEMO_BJ_CREATE.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_DATA) TYPE  ZPRC_DEMO_S_BJ_DATA
*"  EXPORTING
*"     VALUE(EV_ORDER_ID) TYPE  ZPRC_DEMO_BJ_LEG-ORDER_ID
*"  TABLES
*"      RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------
  " BAPI A: creates a legacy document. Classic BAPI behaviour: messages in
  " RETURN (BAPIRET2), posting via update task, no COMMIT WORK of its own.
  " Error modes A* provoke the error cases of the demo.
  STATICS sv_last_number TYPE n LENGTH 10.
  DATA lv_msg TYPE bapi_msg.

  CLEAR ev_order_id.

  IF is_data-description IS INITIAL.
    MESSAGE e001(zprc_demo_bapi_job) INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg ) TO return.
    RETURN.
  ENDIF.

  CASE is_data-error_mode.
    WHEN 'AE'.
      MESSAGE e020(zprc_demo_bapi_job) WITH 'A' INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg message_v1 = sy-msgv1 ) TO return.
      RETURN.
    WHEN 'AM'.
      MESSAGE e021(zprc_demo_bapi_job) WITH 'A'.      " unclean BAPI: MESSAGE instead of RETURN
    WHEN 'AX'.
      MESSAGE x022(zprc_demo_bapi_job) WITH 'A'.
    WHEN 'AL'.
      MESSAGE e023(zprc_demo_bapi_job) WITH 'A' 'OTHER_USER' INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                      message_v1 = sy-msgv1 message_v2 = sy-msgv2 ) TO return.
      RETURN.
  ENDCASE.

  " Number assignment like a number range: exclusive, until the update has written
  " the document (scope 2). Parallel callers wait - otherwise two of them read the
  " same MAX and get the same number.
  CALL FUNCTION 'ENQUEUE_E_TABLE'
    EXPORTING
      mode_rstable   = 'E'
      tabname        = 'ZPRC_DEMO_BJ_LEG'
      _scope         = '2'
      _wait          = abap_true
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    MESSAGE e003(zprc_demo_bapi_job) WITH sy-msgv1 INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                    message_v1 = sy-msgv1 ) TO return.
    RETURN.
  ENDIF.

  SELECT MAX( order_id ) FROM zprc_demo_bj_leg INTO @DATA(lv_max).
  DATA(lv_next) = nmax( val1 = CONV i( lv_max ) val2 = CONV i( sv_last_number ) ) + 1.
  sv_last_number = lv_next.
  ev_order_id = sv_last_number.

  CALL FUNCTION 'Z_PRC_DEMO_BJ_POST' IN UPDATE TASK
    EXPORTING
      iv_order_id = ev_order_id
      is_data     = is_data.

  IF is_data-error_mode = 'AC'.
    COMMIT WORK.                                      " forbidden for a BAPI
  ENDIF.

  MESSAGE s010(zprc_demo_bapi_job) WITH is_data-ref_order_uuid ev_order_id INTO lv_msg.
  APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                  message_v2 = sy-msgv2 ) TO return.
ENDFUNCTION.
