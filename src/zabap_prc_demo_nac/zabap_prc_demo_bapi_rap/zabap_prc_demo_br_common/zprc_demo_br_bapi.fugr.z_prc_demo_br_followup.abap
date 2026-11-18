FUNCTION Z_PRC_DEMO_BR_FOLLOWUP.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_TESTRUN) TYPE  ABAP_BOOLEAN DEFAULT ABAP_FALSE
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BR_LEG-ORDER_ID
*"  TABLES
*"      RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------
  " BAPI B: creates a follow-up for a document of BAPI A.
  " Like many SAP BAPIs it reads its input from the DATABASE - so the
  " document of BAPI A must be committed before this BAPI is called.
  DATA lv_msg TYPE bapi_msg.

  SELECT SINGLE description FROM zprc_demo_br_leg
    WHERE order_id = @iv_order_id
    INTO @DATA(lv_description).
  IF sy-subrc <> 0.
    MESSAGE e003(zprc_demo_bapi_rap) WITH iv_order_id INTO lv_msg.
    APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                    message_v1 = sy-msgv1 ) TO return.
    RETURN.
  ENDIF.

  IF iv_testrun = abap_true.
    RETURN.
  ENDIF.

  CALL FUNCTION 'Z_PRC_DEMO_BR_FOLLOWUP_POST' IN UPDATE TASK
    EXPORTING
      iv_order_id    = iv_order_id
      iv_description = lv_description.

  MESSAGE s011(zprc_demo_bapi_rap) WITH iv_order_id INTO lv_msg.
  APPEND VALUE #( type = sy-msgty id = sy-msgid number = sy-msgno message = lv_msg
                  message_v1 = sy-msgv1 ) TO return.
ENDFUNCTION.
