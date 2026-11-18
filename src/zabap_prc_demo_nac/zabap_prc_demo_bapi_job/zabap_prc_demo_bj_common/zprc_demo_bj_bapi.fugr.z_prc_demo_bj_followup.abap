FUNCTION Z_PRC_DEMO_BJ_FOLLOWUP.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BJ_LEG-ORDER_ID
*"     VALUE(IV_ERROR_MODE) TYPE  ZPRC_DEMO_BJ_ERROR_MODE OPTIONAL
*"  TABLES
*"      RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------
  " BAPI B: creates a follow-up for a document of BAPI A. It reads the document
  " from the DATABASE - so BAPI A must be committed before.
  " Error modes B* provoke the error cases of the demo.
  DATA lv_msg TYPE bapi_msg.

  SELECT SINGLE description FROM zprc_demo_bj_leg
    WHERE order_id = @iv_order_id
    INTO @DATA(lv_description).
  IF sy-subrc <> 0.
    MESSAGE e002(zprc_demo_bapi_job) WITH iv_order_id INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg message_v1 = sy-msgv1 ) TO return.
    RETURN.
  ENDIF.

  CASE iv_error_mode.
    WHEN 'BE'.
      MESSAGE e020(zprc_demo_bapi_job) WITH 'B' INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg message_v1 = sy-msgv1 ) TO return.
      RETURN.
    WHEN 'BM'.
      MESSAGE e021(zprc_demo_bapi_job) WITH 'B'.
    WHEN 'BX'.
      MESSAGE x022(zprc_demo_bapi_job) WITH 'B'.
    WHEN 'BL'.
      MESSAGE e023(zprc_demo_bapi_job) WITH 'B' 'OTHER_USER' INTO lv_msg.
      APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                      message_v1 = sy-msgv1 message_v2 = sy-msgv2 ) TO return.
      RETURN.
  ENDCASE.

  CALL FUNCTION 'Z_PRC_DEMO_BJ_FOLLOWUP_POST' IN UPDATE TASK
    EXPORTING
      iv_order_id    = iv_order_id
      iv_description = lv_description
      iv_error_mode  = iv_error_mode.

  IF iv_error_mode = 'BC'.
    COMMIT WORK.                                      " forbidden for a BAPI
  ENDIF.

  MESSAGE s011(zprc_demo_bapi_job) WITH space iv_order_id INTO lv_msg.
  APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                  message_v2 = sy-msgv2 ) TO return.
ENDFUNCTION.
