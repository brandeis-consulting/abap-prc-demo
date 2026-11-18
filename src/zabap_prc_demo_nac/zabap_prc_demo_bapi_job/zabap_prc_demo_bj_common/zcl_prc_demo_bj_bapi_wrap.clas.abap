"! <p class="shorttext synchronized">BAPI &amp; Jobs: Released wrapper for the demo BAPIs (C1)</p>
"!
"! The bridge between ABAP Cloud and the classic BAPIs: BAPI -> wrapper -> C1.
"! RETURN is passed on, MESSAGE e of unclean BAPIs is caught via
"! EXCEPTIONS error_message, no COMMIT WORK - the job owns the LUW.
CLASS zcl_prc_demo_bj_bapi_wrap DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_order_id TYPE c LENGTH 10.
    " DEFAULT KEY like BAPI return tables - compatible with typed parameters of
    " frameworks, e.g. ZIF_PRC_MESSAGE_HANDLER=>ADD_BAPI_RESULT
    TYPES tt_return   TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY.

    "! BAPI A: create a legacy document
    "!
    "! @parameter i_data     | Data of the document
    "! @parameter e_order_id | Number of the new document
    "! @parameter e_return   | Messages of the BAPI
    CLASS-METHODS create
      IMPORTING i_data     TYPE zprc_demo_s_bj_data
      EXPORTING e_order_id TYPE ty_order_id
                e_return   TYPE tt_return.

    "! BAPI B: follow-up for a legacy document - reads it from the database
    "!
    "! @parameter i_order_id   | The legacy document
    "! @parameter i_error_mode | Error to provoke in BAPI B (demo)
    "! @parameter r_return     | Messages of the BAPI
    CLASS-METHODS followup
      IMPORTING i_order_id      TYPE ty_order_id
                i_error_mode    TYPE zprc_demo_bj_error_mode OPTIONAL
      RETURNING VALUE(r_return) TYPE tt_return.

    "! Demo only: deletes all legacy and follow-up documents. No COMMIT WORK.
    CLASS-METHODS reset_demo_data.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS from_sy
      RETURNING VALUE(r_return) TYPE bapiret2.
ENDCLASS.



CLASS zcl_prc_demo_bj_bapi_wrap IMPLEMENTATION.

  METHOD create.
    CLEAR: e_order_id, e_return.
    CALL FUNCTION 'Z_PRC_DEMO_BJ_CREATE'
      EXPORTING
        is_data       = i_data
      IMPORTING
        ev_order_id   = e_order_id
      TABLES
        return        = e_return
      EXCEPTIONS
        error_message = 1.
    IF sy-subrc <> 0.
      e_return = VALUE #( ( from_sy( ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD followup.
    CALL FUNCTION 'Z_PRC_DEMO_BJ_FOLLOWUP'
      EXPORTING
        iv_order_id   = i_order_id
        iv_error_mode = i_error_mode
      TABLES
        return        = r_return
      EXCEPTIONS
        error_message = 1.
    IF sy-subrc <> 0.
      r_return = VALUE #( ( from_sy( ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD reset_demo_data.
    DELETE FROM zprc_demo_bj_leg.
    DELETE FROM zprc_demo_bj_fup.
  ENDMETHOD.


  METHOD from_sy.
    r_return = VALUE #( type       = sy-msgty
                        id         = sy-msgid
                        number     = sy-msgno
                        message_v1 = sy-msgv1
                        message_v2 = sy-msgv2
                        message_v3 = sy-msgv3
                        message_v4 = sy-msgv4 ).
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO r_return-message.
  ENDMETHOD.

ENDCLASS.
