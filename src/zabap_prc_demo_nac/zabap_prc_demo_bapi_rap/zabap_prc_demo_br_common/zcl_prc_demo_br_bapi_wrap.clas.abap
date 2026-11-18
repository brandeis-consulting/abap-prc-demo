"! <p class="shorttext synchronized">BAPI &amp; RAP: Released wrapper for the demo BAPIs (C1)</p>
"!
"! The bridge between ABAP Cloud and the classic BAPIs: BAPI -> wrapper -> C1.
"! The wrapper is Standard ABAP and released for use in ABAP Cloud (contract C1).
"! It calls the BAPIs exactly like a classic caller would:
"! <ul>
"! <li>RETURN (BAPIRET2) is passed on unchanged</li>
"! <li>MESSAGE e of unclean BAPIs is caught via EXCEPTIONS error_message and
"!     returned as a RETURN line - this is not possible in ABAP Cloud itself</li>
"! <li>no COMMIT WORK - the caller (RAP, PRC, job) owns the LUW</li>
"! </ul>
"! MESSAGE x, MESSAGE a and COMMIT WORK inside a BAPI cannot be caught here either.
CLASS zcl_prc_demo_br_bapi_wrap DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_order_id TYPE c LENGTH 10.
    " DEFAULT KEY like BAPI return tables - compatible with typed parameters of
    " frameworks, e.g. ZIF_PRC_MESSAGE_HANDLER=>ADD_BAPI_RESULT
    TYPES tt_return   TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_document,
             order_id    TYPE ty_order_id,
             description TYPE zprc_demo_s_br_data-description,
           END OF ty_document,
           tt_documents TYPE STANDARD TABLE OF ty_document WITH EMPTY KEY.

    "! BAPI A: create (I_ORDER_ID initial) or change a legacy document
    "!
    "! @parameter i_testrun  | Test run: check only, register nothing
    "! @parameter i_order_id | Document to change; initial = create
    "! @parameter i_data     | Data of the document
    "! @parameter i_datax    | Changed fields (change only)
    "! @parameter e_order_id | Number of the document
    "! @parameter e_return   | Messages of the BAPI
    CLASS-METHODS maintain
      IMPORTING i_testrun  TYPE abap_boolean DEFAULT abap_false
                i_order_id TYPE ty_order_id OPTIONAL
                i_data     TYPE zprc_demo_s_br_data
                i_datax    TYPE zprc_demo_s_br_datax OPTIONAL
      EXPORTING e_order_id TYPE ty_order_id
                e_return   TYPE tt_return.

    "! BAPI B: follow-up for a legacy document - reads it from the database
    "!
    "! @parameter i_order_id | The legacy document
    "! @parameter r_return   | Messages of the BAPI
    CLASS-METHODS followup
      IMPORTING i_order_id      TYPE ty_order_id
      RETURNING VALUE(r_return) TYPE tt_return.

    "! Demo only: replaces all legacy and follow-up documents. No COMMIT WORK.
    "!
    "! @parameter i_documents | The new legacy documents
    CLASS-METHODS reset_demo_data
      IMPORTING i_documents TYPE tt_documents OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS from_sy
      RETURNING VALUE(r_return) TYPE bapiret2.
ENDCLASS.



CLASS zcl_prc_demo_br_bapi_wrap IMPLEMENTATION.

  METHOD maintain.
    CLEAR: e_order_id, e_return.
    CALL FUNCTION 'Z_PRC_DEMO_BR_MAINTAIN'
      EXPORTING
        iv_testrun    = i_testrun
        iv_order_id   = i_order_id
        is_data       = i_data
        is_datax      = i_datax
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
    CALL FUNCTION 'Z_PRC_DEMO_BR_FOLLOWUP'
      EXPORTING
        iv_testrun    = abap_false
        iv_order_id   = i_order_id
      TABLES
        return        = r_return
      EXCEPTIONS
        error_message = 1.
    IF sy-subrc <> 0.
      r_return = VALUE #( ( from_sy( ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD reset_demo_data.
    DELETE FROM zprc_demo_br_leg.
    DELETE FROM zprc_demo_br_fup.

    GET TIME STAMP FIELD DATA(now).
    INSERT zprc_demo_br_leg FROM TABLE @( VALUE #( FOR document IN i_documents
                                                   ( order_id              = document-order_id
                                                     description           = document-description
                                                     local_last_changed_at = now
                                                     last_changed_at       = now ) ) ).
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
