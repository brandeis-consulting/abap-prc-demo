"! Work for the save, collected by the actions. Named like the action that fills it.
"! Keys only. Cleared by the saver's CLEANUP - after every save and after ROLLBACK ENTITIES.
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_keys TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    "! Orders whose process is registered in the save
    CLASS-DATA start_process TYPE tt_keys.
    CLASS-METHODS clear.
ENDCLASS.


CLASS lcl_buffer IMPLEMENTATION.
  METHOD clear.
    CLEAR start_process.
  ENDMETHOD.
ENDCLASS.


"! The latest PRC process per order.
CLASS lcl_process DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_latest,
             order_uuid TYPE sysuuid_x16,
             uuid       TYPE sysuuid_x16,
             state      TYPE zprc_state,
           END OF ty_latest,
           tt_latest TYPE SORTED TABLE OF ty_latest WITH UNIQUE KEY order_uuid.
    TYPES tt_uuids TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    CLASS-METHODS latest
      IMPORTING i_order_uuids   TYPE tt_uuids
      RETURNING VALUE(r_latest) TYPE tt_latest.
ENDCLASS.


CLASS lcl_process IMPLEMENTATION.

  METHOD latest.
    CHECK i_order_uuids IS NOT INITIAL.
    SELECT FROM zr_prc_processedobjecttp
      FIELDS ExternalProcessedObjectUUID, Uuid, State, CreatedAt
      FOR ALL ENTRIES IN @i_order_uuids
      WHERE ExternalProcessedObjectUUID = @i_order_uuids-table_line
        AND ProcessName                 = @zcl_prc_demo_br_pp_proc=>co_process_name
      INTO TABLE @DATA(processes).
    SORT processes BY ExternalProcessedObjectUUID ASCENDING CreatedAt DESCENDING.
    DELETE ADJACENT DUPLICATES FROM processes COMPARING ExternalProcessedObjectUUID.
    r_latest = VALUE #( FOR p IN processes
                        ( order_uuid = p-ExternalProcessedObjectUUID uuid = p-Uuid state = p-State ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_demoorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DemoOrder RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DemoOrder RESULT result.

    METHODS startprocess FOR MODIFY
      IMPORTING keys FOR ACTION DemoOrder~startProcess RESULT result.

    METHODS resumeprocess FOR MODIFY
      IMPORTING keys FOR ACTION DemoOrder~resumeProcess RESULT result.
ENDCLASS.


CLASS lhc_demoorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create               = if_abap_behv=>auth-allowed
                      %update               = if_abap_behv=>auth-allowed
                      %delete               = if_abap_behv=>auth-allowed
                      %action-startProcess  = if_abap_behv=>auth-allowed
                      %action-resumeProcess = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD get_instance_features.
    " Start only without an open process, resume only if the latest one is not finished.
    " Drafts: the remembered start runs in the save of the same request - active only.
    DATA(latest) = lcl_process=>latest( VALUE #( FOR k IN keys ( k-OrderUUID ) ) ).

    LOOP AT keys INTO DATA(key).
      DATA(process) = VALUE #( latest[ order_uuid = key-OrderUUID ] OPTIONAL ).
      DATA(open)    = xsdbool( process-uuid IS NOT INITIAL
                           AND process-state <> zif_prc_process=>co_finished ).
      DATA(draft)   = xsdbool( key-%is_draft = if_abap_behv=>mk-on ).

      APPEND VALUE #( %tky                  = key-%tky
                      %action-startProcess  = COND #( WHEN draft = abap_true OR open = abap_true
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                      %action-resumeProcess = COND #( WHEN draft = abap_false AND open = abap_true
                                                      THEN if_abap_behv=>fc-o-enabled
                                                      ELSE if_abap_behv=>fc-o-disabled ) ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD startprocess.
    " Only remembered - the process is registered in the save sequence
    LOOP AT keys INTO DATA(key).
      INSERT key-OrderUUID INTO TABLE lcl_buffer=>start_process.
    ENDLOOP.

    READ ENTITIES OF zr_prc_demo_br_ppprc IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).
    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).

    " One message per instance, bound to its key: the processing runs asynchronously
    LOOP AT orders INTO DATA(started).
      MESSAGE s030(zprc_demo_bapi_rap) WITH started-Description INTO DATA(text) ##NEEDED.
      APPEND VALUE #( %tky = started-%tky
                      %msg = new_message( id       = sy-msgid
                                          number   = sy-msgno
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = sy-msgv1 ) ) TO reported-demoorder.
    ENDLOOP.
  ENDMETHOD.


  METHOD resumeprocess.
    " Delegates to the PRC: resume the latest, unfinished process of the order.
    " PRIVILEGED: the authorization was checked at the entry point - this BO's
    " authorization handler; the PRC is secondary logic here.
    DATA(latest) = lcl_process=>latest( VALUE #( FOR k IN keys ( k-OrderUUID ) ) ).

    MODIFY ENTITIES OF zr_prc_processedobjecttp PRIVILEGED
           ENTITY ProcessedObject
           EXECUTE resumeProcessing
           FROM VALUE #( FOR l IN latest WHERE ( state <> zif_prc_process=>co_finished )
                         ( %key-uuid = l-uuid ) )
           FAILED DATA(resume_failed) ##NEEDED
           REPORTED DATA(resume_reported) ##NEEDED.

    READ ENTITIES OF zr_prc_demo_br_ppprc IN LOCAL MODE
         ENTITY DemoOrder ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(orders).
    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).

    LOOP AT orders INTO DATA(resumed).
      MESSAGE s031(zprc_demo_bapi_rap) WITH resumed-Description INTO DATA(text) ##NEEDED.
      APPEND VALUE #( %tky = resumed-%tky
                      %msg = new_message( id       = sy-msgid
                                          number   = sy-msgno
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = sy-msgv1 ) ) TO reported-demoorder.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! Saver: registers the PRC process. No BAPI here - so no authorization context:
"! the BAPIs run later in the PRC steps, outside the RAP save phase.
CLASS lsc_zr_prc_demo_br_ppprc DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup       REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_demo_br_ppprc IMPLEMENTATION.

  METHOD save_modified.
    CHECK lcl_buffer=>start_process IS NOT INITIAL.

    " The description is the readable ID of the processed object in the PRC apps
    READ ENTITIES OF zr_prc_demo_br_ppprc IN LOCAL MODE
         ENTITY DemoOrder FIELDS ( Description )
         WITH VALUE #( FOR uuid IN lcl_buffer=>start_process ( OrderUUID = uuid ) )
         RESULT DATA(orders).

    " No COMMIT here: the RAP commit saves the processed objects and starts bgPF.
    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf(
            VALUE #( FOR order IN orders
                     ( processName         = zcl_prc_demo_br_pp_proc=>co_process_name
                       factoryClassName    = zcl_prc_demo_br_pp_proc=>co_class_name
                       processedObject     = order-Description
                       processedObjectUUID = order-OrderUUID ) ) ).
      CATCH cx_bgmc.
        " The processed objects are written anyway: they stay in their start
        " state and the retry job processes them later.
    ENDTRY.
  ENDMETHOD.


  METHOD cleanup.
    " After every save and after ROLLBACK ENTITIES (BDEF: and cleanup)
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.
