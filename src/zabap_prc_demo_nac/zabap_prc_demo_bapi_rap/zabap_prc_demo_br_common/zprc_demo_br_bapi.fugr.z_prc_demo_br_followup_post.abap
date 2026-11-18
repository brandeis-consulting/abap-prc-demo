FUNCTION Z_PRC_DEMO_BR_FOLLOWUP_POST.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BR_LEG-ORDER_ID
*"     VALUE(IV_DESCRIPTION) TYPE  ZPRC_DEMO_BR_LEG-DESCRIPTION
*"----------------------------------------------------------------------
  " Update module of BAPI B: posts the follow-up document after COMMIT WORK.
  GET TIME STAMP FIELD DATA(lv_now).
  MODIFY zprc_demo_br_fup FROM @( VALUE #( order_id    = iv_order_id
                                           description = iv_description
                                           created_at  = lv_now ) ).
ENDFUNCTION.
