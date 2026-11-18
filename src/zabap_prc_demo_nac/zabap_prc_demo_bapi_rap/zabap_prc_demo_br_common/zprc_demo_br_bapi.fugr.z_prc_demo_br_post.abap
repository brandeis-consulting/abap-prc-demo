FUNCTION Z_PRC_DEMO_BR_POST.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ORDER_ID) TYPE  ZPRC_DEMO_BR_LEG-ORDER_ID
*"     VALUE(IS_DATA) TYPE  ZPRC_DEMO_S_BR_DATA
*"     VALUE(IS_DATAX) TYPE  ZPRC_DEMO_S_BR_DATAX
*"     VALUE(IV_CREATE) TYPE  ABAP_BOOLEAN
*"----------------------------------------------------------------------
  " Update module of BAPI A: posts the legacy document after COMMIT WORK.
  " Provoked update terminations (error modes UA / UX) happen here.
  CASE is_data-error_mode.
    WHEN 'UA'.
      MESSAGE a025(zprc_demo_bapi_rap).
    WHEN 'UX'.
      MESSAGE x026(zprc_demo_bapi_rap).
  ENDCASE.

  GET TIME STAMP FIELD DATA(lv_now).

  IF iv_create = abap_true.
    INSERT zprc_demo_br_leg FROM @( VALUE #( order_id              = iv_order_id
                                             ref_order_uuid        = is_data-ref_order_uuid
                                             description           = is_data-description
                                             error_mode            = is_data-error_mode
                                             local_last_changed_at = lv_now
                                             last_changed_at       = lv_now ) ).
    RETURN.
  ENDIF.

  " Change: only the fields flagged in the X structure
  SELECT SINGLE * FROM zprc_demo_br_leg WHERE order_id = @iv_order_id INTO @DATA(ls_doc).
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.
  IF is_datax-description = abap_true.
    ls_doc-description = is_data-description.
  ENDIF.
  IF is_datax-error_mode = abap_true.
    ls_doc-error_mode = is_data-error_mode.
  ENDIF.
  ls_doc-local_last_changed_at = lv_now.
  ls_doc-last_changed_at       = lv_now.
  UPDATE zprc_demo_br_leg FROM @ls_doc.
ENDFUNCTION.
