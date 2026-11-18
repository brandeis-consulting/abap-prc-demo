"! <p class="shorttext synchronized">BAPI &amp; RAP 4: Process state (virtual element)</p>
"!
"! Calculates ProcessState, ProcessMessage and ProcessCriticality of
"! ZC_PRC_DEMO_BR_PpPrc from the latest PRC process started for the order.
"! The object page shows all processes via the association _ProcessedObject.
CLASS zcl_prc_demo_br_pp_state DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_br_pp_state IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #( ( `ORDERUUID` ) ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    TYPES tt_uuids TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    DATA uuids TYPE tt_uuids.

    LOOP AT it_original_data ASSIGNING FIELD-SYMBOL(<original>).
      ASSIGN COMPONENT 'ORDERUUID' OF STRUCTURE <original> TO FIELD-SYMBOL(<uuid>).
      IF sy-subrc = 0.
        INSERT CONV sysuuid_x16( <uuid> ) INTO TABLE uuids.
      ENDIF.
    ENDLOOP.
    CHECK uuids IS NOT INITIAL.

    " Latest process first
    SELECT FROM zr_prc_processedobjecttp
      FIELDS ExternalProcessedObjectUUID, State, MessageText, MessageSeverityCode, CreatedAt
      FOR ALL ENTRIES IN @uuids
      WHERE ExternalProcessedObjectUUID = @uuids-table_line
        AND ProcessName                 = 'DEMO_BAPI_RAP'
      INTO TABLE @DATA(processes).
    SORT processes BY ExternalProcessedObjectUUID ASCENDING CreatedAt DESCENDING.

    LOOP AT ct_calculated_data ASSIGNING FIELD-SYMBOL(<calculated>).
      DATA(index) = sy-tabix.
      ASSIGN it_original_data[ index ] TO <original>.
      ASSIGN COMPONENT 'ORDERUUID' OF STRUCTURE <original> TO <uuid>.
      CHECK <uuid> IS ASSIGNED.

      READ TABLE processes INTO DATA(process)
           WITH KEY ExternalProcessedObjectUUID = <uuid> BINARY SEARCH.
      IF sy-subrc = 0.
        ASSIGN COMPONENT 'PROCESSSTATE'       OF STRUCTURE <calculated> TO FIELD-SYMBOL(<state>).
        ASSIGN COMPONENT 'PROCESSMESSAGE'     OF STRUCTURE <calculated> TO FIELD-SYMBOL(<message>).
        ASSIGN COMPONENT 'PROCESSCRITICALITY' OF STRUCTURE <calculated> TO FIELD-SYMBOL(<criticality>).
        IF <state> IS ASSIGNED.
          <state> = process-State.
        ENDIF.
        IF <message> IS ASSIGNED.
          <message> = process-MessageText.
        ENDIF.
        IF <criticality> IS ASSIGNED.
          <criticality> = process-MessageSeverityCode.
        ENDIF.
        UNASSIGN: <state>, <message>, <criticality>.
      ENDIF.
      UNASSIGN <uuid>.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
