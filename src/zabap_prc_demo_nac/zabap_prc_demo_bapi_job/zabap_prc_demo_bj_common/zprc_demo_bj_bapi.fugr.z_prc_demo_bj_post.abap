FUNCTION Z_PRC_DEMO_BJ_POST.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BJ_LEG-ORDER_ID
*"     VALUE(IS_DATA) TYPE  ZPRC_DEMO_S_BJ_DATA
*"----------------------------------------------------------------------
  " Update module of BAPI A - provoked update terminations AU / AV
  CASE is_data-error_mode.
    WHEN 'AU'.
      MESSAGE a024(zprc_demo_bapi_job) WITH 'A'.
    WHEN 'AV'.
      MESSAGE x025(zprc_demo_bapi_job) WITH 'A'.
  ENDCASE.

  INSERT zprc_demo_bj_leg FROM @( VALUE #( order_id       = iv_order_id
                                           ref_order_uuid = is_data-ref_order_uuid
                                           description    = is_data-description
                                           amount         = is_data-amount
                                           currency       = is_data-currency ) ).
ENDFUNCTION.
