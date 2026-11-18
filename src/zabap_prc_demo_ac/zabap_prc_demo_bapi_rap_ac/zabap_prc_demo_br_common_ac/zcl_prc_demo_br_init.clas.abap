"! <p class="shorttext synchronized">BAPI &amp; RAP: Initialize demo data (F9)</p>
"!
"! Classrun: deletes and recreates the demo data of the BAPI &amp; RAP scenarios.
"! The legacy documents are owned by the BAPIs - they are reset via the
"! released wrapper, not by direct table access. Scenarios 2 and 3 are Standard
"! ABAP and are reset via the released ZCL_PRC_DEMO_BR_NAC_INIT.
CLASS zcl_prc_demo_br_init DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_case,
             error_mode  TYPE zprc_demo_br_error_mode,
             description TYPE c LENGTH 80,
           END OF ty_case,
           tt_cases TYPE STANDARD TABLE OF ty_case WITH EMPTY KEY.

    METHODS get_cases RETURNING VALUE(r_cases) TYPE tt_cases.
ENDCLASS.



CLASS zcl_prc_demo_br_init IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Scenario 4: delete the processed objects of the demo process (own RAP transaction)
    SELECT Uuid FROM zr_prc_processedobjecttp
      WHERE ProcessName = @zcl_prc_demo_br_pp_proc=>co_process_name
      INTO TABLE @DATA(processed).
    IF processed IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
             ENTITY ProcessedObject
             DELETE FROM VALUE #( FOR p IN processed ( %key-uuid = p-uuid ) ).
      COMMIT ENTITIES.
    ENDIF.

    " Scenarios 1, 4, 5: ABAP Cloud tables
    DELETE FROM zprc_demo_bra.
    DELETE FROM zprc_demo_bra_d.
    DELETE FROM zprc_demo_brc.
    DELETE FROM zprc_demo_brc_d.
    DELETE FROM zprc_demo_brq.
    DELETE FROM zprc_demo_brq_d.

    " Scenarios 2, 3: Standard ABAP - reset via the released class
    zcl_prc_demo_br_nac_init=>reset( ).

    GET TIME STAMP FIELD DATA(now).
    DATA action_orders  TYPE STANDARD TABLE OF zprc_demo_bra WITH EMPTY KEY.
    DATA process_orders TYPE STANDARD TABLE OF zprc_demo_brc WITH EMPTY KEY.
    DATA sql_orders     TYPE STANDARD TABLE OF zprc_demo_brq WITH EMPTY KEY.
    DATA legacy         TYPE zcl_prc_demo_br_bapi_wrap=>tt_documents.

    LOOP AT get_cases( ) INTO DATA(case).
      DATA(index) = sy-tabix.

      " Scenario 1: one order per error mode - press "Call BAPI"
      APPEND VALUE #( order_uuid = xco_cp=>uuid( )->value description = case-description
                      error_mode = case-error_mode
                      local_created_by = sy-uname local_created_at = now
                      local_last_changed_by = sy-uname local_last_changed_at = now
                      last_changed_at = now ) TO action_orders.

      " Scenario 4: one order per error mode - press "Start Process"
      APPEND VALUE #( order_uuid = xco_cp=>uuid( )->value description = case-description
                      error_mode = case-error_mode
                      local_created_by = sy-uname local_created_at = now
                      local_last_changed_by = sy-uname local_last_changed_at = now
                      last_changed_at = now ) TO process_orders.

      " Scenario 2: legacy documents (as if posted by the BAPI) - edit and set an error mode
      APPEND VALUE #( order_id    = |{ index WIDTH = 10 ALIGN = RIGHT PAD = '0' }|
                      description = |Document { index }| ) TO legacy.
    ENDLOOP.

    " Scenario 5: plain orders, changed by ABAP SQL in the late save
    DO 3 TIMES.
      DATA(number) = sy-index.
      APPEND VALUE #( order_uuid = xco_cp=>uuid( )->value description = |Order { number }|
                      amount = CONV #( number * 100 ) currency = 'EUR'
                      local_created_by = sy-uname local_created_at = now
                      local_last_changed_by = sy-uname local_last_changed_at = now
                      last_changed_at = now ) TO sql_orders.
    ENDDO.

    " The legacy documents belong to the BAPIs: reset via the released wrapper
    zcl_prc_demo_br_bapi_wrap=>reset_demo_data( legacy ).

    INSERT zprc_demo_bra FROM TABLE @action_orders.
    INSERT zprc_demo_brc FROM TABLE @process_orders.
    INSERT zprc_demo_brq FROM TABLE @sql_orders.
    COMMIT WORK.

    out->write( |BAPI & RAP demo data initialized: { lines( action_orders ) } orders in scenarios 1 and 4, | &&
                |{ lines( legacy ) } legacy documents in scenario 2, scenario 3 cleared, | &&
                |{ lines( sql_orders ) } orders in scenario 5| ).
  ENDMETHOD.


  METHOD get_cases.
    " Neutral descriptions: the error mode column shows the case as text, and
    " Fiori puts the description (headerInfo title) in front of every message.
    r_cases = VALUE #( ( error_mode = ''   description = 'Order 1' )
                       ( error_mode = 'CE' description = 'Order 2' )
                       ( error_mode = 'SE' description = 'Order 3' )
                       ( error_mode = 'SM' description = 'Order 4' )
                       ( error_mode = 'SX' description = 'Order 5' )
                       ( error_mode = 'SC' description = 'Order 6' )
                       ( error_mode = 'SL' description = 'Order 7' )
                       ( error_mode = 'UA' description = 'Order 8' )
                       ( error_mode = 'UX' description = 'Order 9' ) ).
  ENDMETHOD.

ENDCLASS.
