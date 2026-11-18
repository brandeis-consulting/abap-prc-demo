"! <p class="shorttext synchronized">BAPI &amp; Jobs: BAPIRET2 and error mode helper</p>
CLASS zcl_prc_demo_bj_bapi_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Does RETURN contain an error (types E, A, X)?
    "!
    "! @parameter i_return | Messages of a BAPI
    "! @parameter r_result | abap_true if one of them is an error
    CLASS-METHODS has_error
      IMPORTING i_return        TYPE zcl_prc_demo_bj_bapi_wrap=>tt_return
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! The number of a demo order: ORD0000003 -> 3
    "!
    "! @parameter i_order_id | ID of the demo order
    "! @parameter r_number   | Its number, 0 if it has none
    CLASS-METHODS order_number
      IMPORTING i_order_id      TYPE zprc_demo_bjo-order_id
      RETURNING VALUE(r_number) TYPE i.

    "! The error mode for one BAPI and one order: the job's error mode applies to
    "! the BAPI it names (A* or B*) and to every n-th order only.
    "! "Every n-th order" counts by the order number, not by the position in the
    "! selection - so a rerun hits the same orders as the first run.
    "!
    "! @parameter i_bapi         | A or B
    "! @parameter i_error_mode   | Error mode of the job
    "! @parameter i_order_number | Number of the order
    "! @parameter i_every_nth    | The error hits every n-th order
    "! @parameter r_mode         | Error mode for this BAPI and order, initial if none
    CLASS-METHODS error_mode_for
      IMPORTING i_bapi         TYPE c
                i_error_mode   TYPE zprc_demo_bj_error_mode
                i_order_number TYPE i
                i_every_nth    TYPE i
      RETURNING VALUE(r_mode)  TYPE zprc_demo_bj_error_mode.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_bj_bapi_util IMPLEMENTATION.

  METHOD has_error.
    r_result = xsdbool( line_exists( i_return[ type = 'E' ] )
                     OR line_exists( i_return[ type = 'A' ] )
                     OR line_exists( i_return[ type = 'X' ] ) ).
  ENDMETHOD.


  METHOD order_number.
    TRY.
        r_number = CONV i( substring( val = i_order_id off = 3 ) ).
      CATCH cx_sy_conversion_error cx_sy_range_out_of_bounds ##NO_HANDLER.
        r_number = 0.
    ENDTRY.
  ENDMETHOD.


  METHOD error_mode_for.
    CHECK i_error_mode IS NOT INITIAL
      AND i_error_mode(1) = i_bapi
      AND i_every_nth > 0
      AND i_order_number > 0
      AND i_order_number MOD i_every_nth = 0.
    r_mode = i_error_mode.
  ENDMETHOD.

ENDCLASS.
