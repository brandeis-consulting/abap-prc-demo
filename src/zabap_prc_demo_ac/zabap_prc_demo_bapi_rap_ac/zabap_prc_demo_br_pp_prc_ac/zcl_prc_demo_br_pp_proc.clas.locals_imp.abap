"! Step 1 (START -> LEGACY_CREATED): BAPI A creates the legacy document.
"! The order is committed by RAP, so it is simply read via EML.
"! Header of the step: an own, process-level success message; the BAPI's own
"! success message stays as detail.
CLASS lcl_create_legacy DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
  PRIVATE SECTION.
    DATA order_id TYPE zcl_prc_demo_br_bapi_wrap=>ty_order_id.
ENDCLASS.


CLASS lcl_create_legacy IMPLEMENTATION.

  METHOD perform_transition.
    READ ENTITIES OF zr_prc_demo_br_ppprc
         ENTITY DemoOrder ALL FIELDS
         WITH VALUE #( ( OrderUUID = i_processed_object_ext_uuid ) )
         RESULT DATA(orders).
    DATA(order) = VALUE #( orders[ 1 ] OPTIONAL ).

    zcl_prc_demo_br_bapi_wrap=>maintain(
      EXPORTING i_data     = VALUE #( ref_order_uuid = i_processed_object_ext_uuid
                                      description    = order-Description
                                      error_mode     = order-ErrorMode )
      IMPORTING e_order_id = order_id
                e_return   = DATA(messages) ).

    " An error raises out of the message handler and fails the step.
    " No COMMIT WORK - the engine commits after this method.
    get_message_handler( )->add_bapi_result( messages ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s032(zprc_demo_bapi_rap) WITH order_id INTO DATA(text) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.


"! Step 2 (LEGACY_CREATED -> FINISHED): BAPI B creates the follow-up.
"! BAPI B reads the document of BAPI A from the database - committed by step 1.
CLASS lcl_create_followup DEFINITION INHERITING FROM zcl_prc_transition_handlr_base.
  PROTECTED SECTION.
    METHODS perform_transition  REDEFINITION.
    METHODS get_success_message REDEFINITION.
  PRIVATE SECTION.
    DATA order_id TYPE zcl_prc_demo_br_bapi_wrap=>ty_order_id.
ENDCLASS.


CLASS lcl_create_followup IMPLEMENTATION.

  METHOD perform_transition.
    " Committed by step 1 - read via the released view, no payload needed
    SELECT OrderID FROM zi_prc_demo_br_legacydoc
      WHERE RefOrderUUID = @i_processed_object_ext_uuid
      ORDER BY OrderID DESCENDING
      INTO @order_id
      UP TO 1 ROWS.
    ENDSELECT.

    IF order_id IS INITIAL.
      " Say what is missing instead of calling BAPI B without a document number
      MESSAGE e006(zprc_demo_bapi_rap) WITH i_processed_object_ext_id INTO DATA(text).
      get_message_handler( )->add_bapi_result(
          VALUE #( ( type = sy-msgty id = sy-msgid number = sy-msgno message = text
                     message_v1 = sy-msgv1 ) ) ).
    ENDIF.

    get_message_handler( )->add_bapi_result( zcl_prc_demo_br_bapi_wrap=>followup( order_id ) ).
  ENDMETHOD.


  METHOD get_success_message.
    MESSAGE s033(zprc_demo_bapi_rap) WITH order_id INTO DATA(text) ##NEEDED.
    r_message = sy_message( ).
  ENDMETHOD.

ENDCLASS.
