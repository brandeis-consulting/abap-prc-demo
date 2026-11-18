"! <p class="shorttext synchronized">BAPI &amp; RAP: BAPIRET2 helper</p>
"!
"! <ul>
"! <li>HAS_ERROR - does RETURN contain an error (types E, A, X)?</li>
"! <li>TO_SEVERITY - BAPIRET2 message type as RAP severity</li>
"! </ul>
"! The RAP messages themselves are created with the built-in NEW_MESSAGE of the
"! handler and saver classes - from ID, number and variables of the BAPI message,
"! so the text is resolved in the user's language.
CLASS zcl_prc_demo_br_bapi_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter i_return | Messages of a BAPI
    "! @parameter r_result | abap_true if one of them is an error
    CLASS-METHODS has_error
      IMPORTING i_return        TYPE zcl_prc_demo_br_bapi_wrap=>tt_return
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! @parameter i_type     | Message type of a BAPI message
    "! @parameter r_severity | The RAP severity
    CLASS-METHODS to_severity
      IMPORTING i_type            TYPE bapiret2-type
      RETURNING VALUE(r_severity) TYPE if_abap_behv_message=>t_severity.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_br_bapi_util IMPLEMENTATION.

  METHOD has_error.
    r_result = xsdbool( line_exists( i_return[ type = 'E' ] )
                     OR line_exists( i_return[ type = 'A' ] )
                     OR line_exists( i_return[ type = 'X' ] ) ).
  ENDMETHOD.


  METHOD to_severity.
    r_severity = SWITCH #( i_type
                   WHEN 'E' OR 'A' OR 'X' THEN if_abap_behv_message=>severity-error
                   WHEN 'W'               THEN if_abap_behv_message=>severity-warning
                   WHEN 'S'               THEN if_abap_behv_message=>severity-success
                   ELSE                        if_abap_behv_message=>severity-information ).
  ENDMETHOD.

ENDCLASS.
