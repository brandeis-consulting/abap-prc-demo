CLASS lhe_equipment DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_equipment_created FOR ENTITY EVENT
      equipment_created FOR Equipment~equipment_created.

ENDCLASS.

CLASS lhe_equipment IMPLEMENTATION.
  METHOD on_equipment_created.
    cl_abap_tx=>save( ).

    TRY.
        zcl_prc_processing_api=>get_instance( )->create_and_schedule_bgpf(
          VALUE #( FOR k IN equipment_created
                   ( processedObject  = k-Identifier
                     processName      = zcl_prc_demo_equi_assign_proc=>co_process_name
                     factoryClassName = zcl_prc_demo_equi_assign_proc=>co_class_name
                     " Recipient of the error notification (job ZAJT_PRC_ERROR_NOTIFICATION)
                     mailAddress      = 'demo@abap-processing-center.de' ) ) ).
      CATCH cx_bgmc.
        " Decision of this consumer: the equipment is saved already, so the objects are kept.
        " They stay in their start state and the retry job assigns the equipment later.
        " A consumer that must not continue without immediate processing rolls back instead.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
