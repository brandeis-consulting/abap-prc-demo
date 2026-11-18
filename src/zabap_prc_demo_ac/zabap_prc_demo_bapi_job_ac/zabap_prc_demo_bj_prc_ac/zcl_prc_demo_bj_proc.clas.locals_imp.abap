"! Step 1 (START -> LEGACY_CREATED): BAPI A creates the legacy document.
"! Header of the step: an own, process-level success message; the BAPI's own
"! success message stays as detail.
CLASS lcl_create_legacy DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
  PRIVATE SECTION.
    DATA order_id TYPE zcl_prc_demo_bj_bapi_wrap=>ty_order_id.
ENDCLASS.


CLASS lcl_create_legacy IMPLEMENTATION.

  METHOD perform_transition.
    SELECT SINGLE * FROM zprc_demo_bjo
      WHERE order_uuid = @i_processed_object_ext_uuid
      INTO @DATA(order).

    zcl_prc_demo_bj_bapi_wrap=>create(
      EXPORTING i_data     = VALUE #( ref_order_uuid = i_processed_object_ext_uuid
                                      description    = order-description
                                      amount         = order-amount
                                      currency       = order-currency
                                      error_mode     = zcl_prc_demo_bj_proc=>from_payload( c_payload_json )-mode_a )
      IMPORTING e_order_id = order_id
                e_return   = DATA(messages) ).

    " Error -> step fails. No COMMIT WORK - the engine commits.
    get_message_handler( )->add_bapi_result( messages ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s030(zprc_demo_bapi_job) WITH order_id INTO DATA(text) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.


"! Step 2 (LEGACY_CREATED -> FINISHED): BAPI B creates the follow-up.
"! It reads the document of BAPI A from the database - committed by step 1.
CLASS lcl_create_followup DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
  PRIVATE SECTION.
    DATA order_id TYPE zcl_prc_demo_bj_bapi_wrap=>ty_order_id.
ENDCLASS.


CLASS lcl_create_followup IMPLEMENTATION.

  METHOD perform_transition.
    " Committed by step 1 - read via the released view
    SELECT OrderID FROM zi_prc_demo_bj_legacydoc
      WHERE RefOrderUUID = @i_processed_object_ext_uuid
      ORDER BY OrderID DESCENDING
      INTO @order_id
      UP TO 1 ROWS.
    ENDSELECT.

    IF order_id IS INITIAL.
      " Say what is missing instead of calling BAPI B without a document number
      MESSAGE e004(zprc_demo_bapi_job) WITH i_processed_object_ext_id INTO DATA(text).
      get_message_handler( )->add_bapi_result(
          VALUE #( ( type = sy-msgty id = sy-msgid number = sy-msgno message = text
                     message_v1 = sy-msgv1 ) ) ).
    ENDIF.

    get_message_handler( )->add_bapi_result(
        zcl_prc_demo_bj_bapi_wrap=>followup(
          i_order_id   = order_id
          i_error_mode = zcl_prc_demo_bj_proc=>from_payload( c_payload_json )-mode_b ) ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s031(zprc_demo_bapi_job) WITH order_id INTO DATA(text) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
