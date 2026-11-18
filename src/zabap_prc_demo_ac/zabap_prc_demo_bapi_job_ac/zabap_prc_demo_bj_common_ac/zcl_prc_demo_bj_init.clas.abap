"! <p class="shorttext synchronized">BAPI &amp; Jobs: Initialize demo orders (F9)</p>
"!
"! Deletes all orders of the job demo, the legacy and follow-up documents (via the
"! released wrapper) and the processed objects of process DEMO_BAPI_JOB, and
"! creates 10 new demo orders. Run with F9 before starting a job.
CLASS zcl_prc_demo_bj_init DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_bj_init IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Processed objects of the demo process (own RAP transaction)
    SELECT Uuid FROM zr_prc_processedobjecttp
      WHERE ProcessName = @zcl_prc_demo_bj_proc=>co_process_name
      INTO TABLE @DATA(processed).
    IF processed IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
             ENTITY ProcessedObject
             DELETE FROM VALUE #( FOR p IN processed ( %key-uuid = p-uuid ) ).
      COMMIT ENTITIES.
    ENDIF.

    " Runs of the demo application - otherwise they stay with "0 of n" processed objects
    SELECT UUID FROM zr_prc_runtp
      WHERE ApplicationName = @zcl_prc_demo_bj_prc_job=>co_application_name
      INTO TABLE @DATA(runs).
    IF runs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prc_runtp PRIVILEGED
             ENTITY Run
             DELETE FROM VALUE #( FOR r IN runs ( %key-uuid = r-uuid ) ).
      COMMIT ENTITIES.
    ENDIF.

    DELETE FROM zprc_demo_bjo.
    " The legacy documents belong to the BAPIs: reset via the released wrapper
    zcl_prc_demo_bj_bapi_wrap=>reset_demo_data( ).

    DATA orders TYPE STANDARD TABLE OF zprc_demo_bjo WITH EMPTY KEY.
    DO 10 TIMES.
      DATA(index) = sy-index.
      APPEND VALUE #( order_uuid  = xco_cp=>uuid( )->value
                      order_id    = |ORD{ index WIDTH = 7 ALIGN = RIGHT PAD = '0' }|
                      description = |Demo order { index }|
                      amount      = CONV #( index * 100 )
                      currency    = 'EUR' ) TO orders.
    ENDDO.
    INSERT zprc_demo_bjo FROM TABLE @orders.
    COMMIT WORK.

    DATA(count) = lines( orders ).
    MESSAGE s016(zprc_demo_bapi_job) WITH count INTO DATA(text).
    out->write( text ).
  ENDMETHOD.

ENDCLASS.
