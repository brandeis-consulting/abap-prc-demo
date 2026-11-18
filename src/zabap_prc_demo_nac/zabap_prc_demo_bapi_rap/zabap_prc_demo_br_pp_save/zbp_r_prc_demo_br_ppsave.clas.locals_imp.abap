"! The follow-up document of an order, found via the released view (reference UUID).
CLASS lcl_legacy DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_document,
             order_uuid TYPE sysuuid_x16,
             order_id   TYPE zcl_prc_demo_br_bapi_wrap=>ty_order_id,
           END OF ty_document,
           tt_documents TYPE SORTED TABLE OF ty_document WITH UNIQUE KEY order_uuid.
    TYPES tt_uuids TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    CLASS-METHODS documents
      IMPORTING i_order_uuids      TYPE tt_uuids
      RETURNING VALUE(r_documents) TYPE tt_documents.
ENDCLASS.


CLASS lcl_legacy IMPLEMENTATION.

  METHOD documents.
    CHECK i_order_uuids IS NOT INITIAL.
    SELECT RefOrderUUID, OrderID
      FROM zi_prc_demo_br_legacydoc
      FOR ALL ENTRIES IN @i_order_uuids
      WHERE RefOrderUUID = @i_order_uuids-table_line
      INTO TABLE @DATA(found).
    " Latest document per order
    SORT found BY RefOrderUUID ASCENDING OrderID DESCENDING.
    DELETE ADJACENT DUPLICATES FROM found COMPARING RefOrderUUID.
    r_documents = VALUE #( FOR document IN found ( order_uuid = document-RefOrderUUID order_id = document-OrderID ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_demoorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DemoOrder RESULT result.

    METHODS checkwithbapi FOR VALIDATE ON SAVE
      IMPORTING keys FOR DemoOrder~checkWithBapi.
ENDCLASS.


CLASS lhc_demoorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    " The BO's OWN authorization check belongs here - in the interaction phase,
    " whatever it looks like for your BO (demo: everything allowed).
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD checkwithbapi.
    " BAPI test run on the final state - state messages stay with the draft.
    " New order: test run of the create; existing order: test run of the change
    " of its follow-up document.
    " Validations run in the early save, where AUTHORITY-CHECK is not allowed.
    " Standard ABAP can disable the BAPI's own check explicitly - ABAP Cloud cannot.
    READ ENTITIES OF zr_prc_demo_br_ppsave IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).
    DATA(documents) = lcl_legacy=>documents( VALUE #( FOR o IN orders ( o-OrderUUID ) ) ).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'CHECK_BAPI' ) TO reported-demoorder.
      DATA(order_id) = VALUE #( documents[ order_uuid = order-OrderUUID ]-order_id OPTIONAL ).

      AUTHORITY-CHECK DISABLE BEGIN CONTEXT zr_prc_demo_br_ppsave~NoCheckWhenSaving.
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_testrun  = abap_true
                  i_order_id = order_id             " initial = create
                  i_data     = CORRESPONDING #( order MAPPING FROM ENTITY )
                  i_datax    = VALUE #( description = abap_true error_mode = abap_true )
        IMPORTING e_return   = DATA(messages) ).
      AUTHORITY-CHECK DISABLE END.

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( %tky = order-%tky ) TO failed-demoorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( %tky        = order-%tky
                        %state_area = 'CHECK_BAPI'
                        %msg        = new_message( id       = message-id
                                                   number   = message-number
                                                   severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                                   v1       = message-message_v1
                                                   v2       = message-message_v2
                                                   v3       = message-message_v3
                                                   v4       = message-message_v4 ) ) TO reported-demoorder.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! Saver: the follow-up document in the same LUW - created with the order,
"! changed with the order. CL_ABAP_BEHAVIOR_SAVER_FAILED: a BAPI error rolls
"! back order and follow-up together.
CLASS lsc_zr_prc_demo_br_ppsave DEFINITION INHERITING FROM cl_abap_behavior_saver_failed.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_demo_br_ppsave IMPLEMENTATION.

  METHOD save_modified.
    " The BAPI's authority checks are disabled automatically (save:late).
    TYPES: BEGIN OF ty_call,
             order_uuid TYPE sysuuid_x16,
             order_id   TYPE zcl_prc_demo_br_bapi_wrap=>ty_order_id,
             data       TYPE zprc_demo_s_br_data,
             datax      TYPE zprc_demo_s_br_datax,
           END OF ty_call.
    DATA calls TYPE STANDARD TABLE OF ty_call WITH EMPTY KEY.

    " Create: CREATE-DEMOORDER holds the complete, current data of the new orders
    LOOP AT create-demoorder INTO DATA(new_order).
      APPEND VALUE #( order_uuid = new_order-OrderUUID
                      data       = VALUE #( BASE CORRESPONDING #( new_order MAPPING FROM ENTITY )
                                            ref_order_uuid = new_order-OrderUUID ) ) TO calls.
    ENDLOOP.

    " Change: the follow-up document is changed too - only the changed fields (%control)
    IF update-demoorder IS NOT INITIAL.
      DATA(documents) = lcl_legacy=>documents( VALUE #( FOR u IN update-demoorder ( u-OrderUUID ) ) ).
      LOOP AT update-demoorder INTO DATA(change).
        DATA(order_id) = VALUE #( documents[ order_uuid = change-OrderUUID ]-order_id OPTIONAL ).
        CHECK order_id IS NOT INITIAL.
        APPEND VALUE #( order_uuid = change-OrderUUID
                        order_id   = order_id
                        data       = CORRESPONDING #( change MAPPING FROM ENTITY )
                        datax      = CORRESPONDING #( change MAPPING FROM ENTITY USING CONTROL ) ) TO calls.
      ENDLOOP.
    ENDIF.

    LOOP AT calls INTO DATA(call).
      zcl_prc_demo_br_bapi_wrap=>maintain(
        EXPORTING i_order_id = call-order_id    " initial = create
                  i_data     = call-data
                  i_datax    = call-datax
        IMPORTING e_return   = DATA(messages) ).

      CHECK zcl_prc_demo_br_bapi_util=>has_error( messages ).
      APPEND VALUE #( OrderUUID = call-order_uuid ) TO failed-demoorder.
      LOOP AT messages INTO DATA(message).
        APPEND VALUE #( OrderUUID = call-order_uuid
                        %msg      = new_message( id       = message-id
                                                 number   = message-number
                                                 severity = zcl_prc_demo_br_bapi_util=>to_severity( message-type )
                                                 v1       = message-message_v1
                                                 v2       = message-message_v2
                                                 v3       = message-message_v3
                                                 v4       = message-message_v4 ) ) TO reported-demoorder.
      ENDLOOP.
    ENDLOOP.

    " Negative example (do NOT do this): calling BAPI B here, in the same LUW.
    " BAPI A's document is only written by its update module during the commit,
    " so BAPI B does not find it -> error 003. See scenario 4.
    " No COMMIT WORK - the follow-up document is committed together with the order
  ENDMETHOD.

ENDCLASS.
