FUNCTION Z_PRC_DEMO_BJ_FOLLOWUP_POST.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BJ_LEG-ORDER_ID
*"     VALUE(IV_DESCRIPTION) TYPE  ZPRC_DEMO_BJ_LEG-DESCRIPTION
*"     VALUE(IV_ERROR_MODE) TYPE  ZPRC_DEMO_BJ_ERROR_MODE
*"----------------------------------------------------------------------
  " Update module of BAPI B - provoked update terminations BU / BV
  CASE iv_error_mode.
    WHEN 'BU'.
      MESSAGE a024(zprc_demo_bapi_job) WITH 'B'.
    WHEN 'BV'.
      MESSAGE x025(zprc_demo_bapi_job) WITH 'B'.
  ENDCASE.

  GET TIME STAMP FIELD DATA(lv_now).
  MODIFY zprc_demo_bj_fup FROM @( VALUE #( order_id    = iv_order_id
                                           description = iv_description
                                           created_at  = lv_now ) ).
ENDFUNCTION.
