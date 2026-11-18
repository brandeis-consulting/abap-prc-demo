"! <p class="shorttext synchronized">BAPI &amp; Jobs: Application job without PRC</p>
"!
"! Per order: BAPI A, COMMIT WORK AND WAIT, BAPI B, COMMIT WORK AND WAIT.
"! A job without framework with very good logging:
"! <ul>
"! <li>Every log entry of an order starts with the order ID</li>
"! <li>"Processing started" is logged and saved before the work - after a dump the
"!     last entry names the order</li>
"! <li>The application log (object ZPRC_DEMO_BJ, sub object PLAIN_JOB) is attached to
"!     the job and saved via a second DB connection before and after every order -
"!     it survives ROLLBACK WORK and a dump</li>
"! <li>Small LUWs: RETURN errors and MESSAGE e (caught in the wrapper): ROLLBACK WORK,
"!     next order; update terminations: sy-subrc after COMMIT WORK AND WAIT</li>
"! </ul>
"! Not idempotent - on purpose: a rerun processes all selected orders again and posts
"! the already processed ones twice. Not catchable: MESSAGE x / a raised directly in
"! a BAPI - the whole job is canceled and the remaining orders are not processed.
"! ABAP Cloud: the BAPIs are called via the released wrapper ZCL_PRC_DEMO_BJ_BAPI_WRAP.
"!
"! Run as application job (parameters S_ORDER, P_ERROR, P_NTH) or with F9.
CLASS zcl_prc_demo_bj_plain_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.

    CONSTANTS: BEGIN OF co_parameter,
                 order      TYPE c LENGTH 8 VALUE 'S_ORDER',
                 error_mode TYPE c LENGTH 8 VALUE 'P_ERROR',
                 every_nth  TYPE c LENGTH 8 VALUE 'P_NTH',
               END OF co_parameter.

    TYPES tt_texts TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    TYPES tt_order_range TYPE RANGE OF zprc_demo_bjo-order_id.

    "! Processes the selected orders, writes the application log and returns its texts
    "!
    "! @parameter i_orders        | Orders to process; empty = all
    "! @parameter i_error_mode    | Error to provoke (demo)
    "! @parameter i_every_nth     | The error hits every n-th order
    "! @parameter i_attach_to_job | Attach the log to the running application job
    "! @parameter r_texts         | The texts of the log
    METHODS run
      IMPORTING i_orders        TYPE tt_order_range OPTIONAL
                i_error_mode    TYPE zprc_demo_bj_error_mode OPTIONAL
                i_every_nth     TYPE i DEFAULT 3
                i_attach_to_job TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(r_texts)  TYPE tt_texts.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA texts         TYPE tt_texts.
    DATA log           TYPE REF TO if_bali_log.
    DATA attach_to_job TYPE abap_bool.

    "! BAPI messages of an order: prefixed with the order ID (message 018)
    METHODS log_return
      IMPORTING i_return   TYPE zcl_prc_demo_bj_bapi_wrap=>tt_return
                i_order_id TYPE zprc_demo_bjo-order_id.
    "! The message in SY-MSG*
    METHODS log_message.
    METHODS save_log.
ENDCLASS.



CLASS zcl_prc_demo_bj_plain_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    " ABAP Cloud: no value help for job parameters (component_type is not used),
    " so the possible values are part of the parameter text
    et_parameter_def = VALUE #(
        changeable_ind = abap_true
        ( selname = co_parameter-order      kind = if_apj_dt_exec_object=>select_option
          datatype = 'C' length = 10 param_text = 'Order (ORD0000001 - ORD0000010)' )
        ( selname = co_parameter-error_mode kind = if_apj_dt_exec_object=>parameter
          datatype = 'C' length = 2
          param_text = 'Provoked error - 1st letter: A = BAPI A, B = BAPI B; 2nd letter: E = error message, M = MESSAGE E, X = MESSAGE X, C = COMMIT WORK, L = lock error, U = update task MESSAGE A, V = update task MESSAGE X (e.g. AE, BX)' )
        ( selname = co_parameter-every_nth  kind = if_apj_dt_exec_object=>parameter
          datatype = 'I' length = 10 param_text = 'Error for every n-th order (default 3)' ) ).
    et_parameter_val = VALUE #( ( selname = co_parameter-every_nth kind = if_apj_dt_exec_object=>parameter
                                  sign = 'I' option = 'EQ' low = '3' ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA orders     TYPE tt_order_range.
    DATA error_mode TYPE zprc_demo_bj_error_mode.
    DATA every_nth  TYPE i VALUE 3.

    LOOP AT it_parameters INTO DATA(parameter).
      CASE parameter-selname.
        WHEN co_parameter-order.
          APPEND VALUE #( sign = parameter-sign option = parameter-option
                          low  = parameter-low  high   = parameter-high ) TO orders.
        WHEN co_parameter-error_mode.
          error_mode = parameter-low.
        WHEN co_parameter-every_nth.
          every_nth = parameter-low.
      ENDCASE.
    ENDLOOP.

    run( i_orders = orders i_error_mode = error_mode i_every_nth = every_nth i_attach_to_job = abap_true ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " F9: change the error mode here to try the cases
    out->write( run( i_error_mode = 'AE' i_every_nth = 3 ) ).
  ENDMETHOD.


  METHOD run.
    DATA completed TYPE i.
    DATA failed    TYPE i.

    CLEAR texts.
    attach_to_job = i_attach_to_job.
    TRY.
        log = cl_bali_log=>create_with_header(
                cl_bali_header_setter=>create( object    = 'ZPRC_DEMO_BJ'
                                               subobject = 'PLAIN_JOB' ) ).
      CATCH cx_bali_runtime INTO DATA(bali_error).
        " No log - the job still runs, but says why
        CLEAR log.
        APPEND |E: Application log not created: { bali_error->get_text( ) }| TO texts.
    ENDTRY.

    " No own status: every run processes all selected orders. Not idempotent -
    " a rerun after a cancellation posts the already processed orders again.
    SELECT * FROM zprc_demo_bjo
      WHERE order_id IN @i_orders
      ORDER BY order_id
      INTO TABLE @DATA(orders).

    LOOP AT orders INTO DATA(order).
      " Every n-th order by order number
      DATA(number) = zcl_prc_demo_bj_bapi_util=>order_number( order-order_id ).

      " Saved BEFORE the work: if the order dumps, the log shows which one it was
      MESSAGE i017(zprc_demo_bapi_job) WITH order-order_id INTO DATA(text) ##NEEDED.
      log_message( ).
      save_log( ).

      " Step 1: BAPI A
      zcl_prc_demo_bj_bapi_wrap=>create(
        EXPORTING i_data   = VALUE #( ref_order_uuid = order-order_uuid
                                      description    = order-description
                                      amount         = order-amount
                                      currency       = order-currency
                                      error_mode     = zcl_prc_demo_bj_bapi_util=>error_mode_for(
                                                         i_bapi = 'A' i_error_mode = i_error_mode
                                                         i_order_number = number i_every_nth = i_every_nth ) )
        IMPORTING e_return = DATA(messages) ).
      IF zcl_prc_demo_bj_bapi_util=>has_error( messages ).
        ROLLBACK WORK.                       " also discards the registered update
        log_return( i_return = messages i_order_id = order-order_id ).
        failed += 1.
        save_log( ).
        CONTINUE.
      ENDIF.

      COMMIT WORK AND WAIT.
      IF sy-subrc <> 0.                      " update termination (asynchronous update, SM13)
        MESSAGE e013(zprc_demo_bapi_job) WITH order-order_id INTO text.
        log_message( ).
        failed += 1.
        save_log( ).
        CONTINUE.
      ENDIF.
      log_return( i_return = messages i_order_id = order-order_id ).
      save_log( ).

      " Step 2: BAPI B - reads the document of BAPI A, committed above (released view)
      SELECT OrderID FROM zi_prc_demo_bj_legacydoc
        WHERE RefOrderUUID = @order-order_uuid
        ORDER BY OrderID DESCENDING
        INTO @DATA(legacy_id)
        UP TO 1 ROWS.
      ENDSELECT.

      messages = zcl_prc_demo_bj_bapi_wrap=>followup(
                   i_order_id   = legacy_id
                   i_error_mode = zcl_prc_demo_bj_bapi_util=>error_mode_for(
                                    i_bapi = 'B' i_error_mode = i_error_mode
                                    i_order_number = number i_every_nth = i_every_nth ) ).
      IF zcl_prc_demo_bj_bapi_util=>has_error( messages ).
        ROLLBACK WORK.
        log_return( i_return = messages i_order_id = order-order_id ).
        failed += 1.
        save_log( ).
        CONTINUE.
      ENDIF.

      COMMIT WORK AND WAIT.
      IF sy-subrc <> 0.
        MESSAGE e013(zprc_demo_bapi_job) WITH order-order_id INTO text.
        log_message( ).
        failed += 1.
        save_log( ).
        CONTINUE.
      ENDIF.
      log_return( i_return = messages i_order_id = order-order_id ).

      MESSAGE s014(zprc_demo_bapi_job) WITH order-order_id INTO text.
      log_message( ).
      completed += 1.
      save_log( ).
    ENDLOOP.

    DATA(selected) = lines( orders ).
    MESSAGE s015(zprc_demo_bapi_job) WITH selected completed failed INTO DATA(summary) ##NEEDED.
    log_message( ).
    save_log( ).
    r_texts = texts.
  ENDMETHOD.


  METHOD log_return.
    " The BAPI's message text behind the order ID: "ORD0000003: <BAPI message>".
    " The text is split into message variables of 50 characters. Trailing blanks of
    " a variable are lost, so a split happens before a blank: the blank leads the next part.
    TYPES ty_part TYPE c LENGTH 50.
    DATA parts TYPE STANDARD TABLE OF ty_part WITH EMPTY KEY.

    LOOP AT i_return INTO DATA(message).
      CLEAR parts.
      DATA(rest) = CONV string( message-message ).
      WHILE rest IS NOT INITIAL AND lines( parts ) < 3.
        IF strlen( rest ) <= 50.
          APPEND rest TO parts.
          CLEAR rest.
        ELSE.
          " Last blank within the first 50 characters - split before it
          DATA(split) = find( val = substring( val = rest len = 50 ) sub = ` ` occ = -1 ).
          IF split <= 0.
            split = 50.
          ENDIF.
          APPEND substring( val = rest len = split ) TO parts.
          rest = substring( val = rest off = split ).
        ENDIF.
      ENDWHILE.

      MESSAGE ID 'ZPRC_DEMO_BAPI_JOB' TYPE message-type NUMBER '018'
              WITH i_order_id
                   VALUE ty_part( parts[ 1 ] OPTIONAL )
                   VALUE ty_part( parts[ 2 ] OPTIONAL )
                   VALUE ty_part( parts[ 3 ] OPTIONAL )
              INTO DATA(text) ##NEEDED.
      log_message( ).
    ENDLOOP.
  ENDMETHOD.


  METHOD log_message.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO DATA(text).
    APPEND |{ sy-msgty }: { text }| TO texts.

    CHECK log IS BOUND.
    DATA(severity) = SWITCH #( sy-msgty
                       WHEN 'E' OR 'A' OR 'X' THEN if_bali_constants=>c_severity_error
                       WHEN 'W'               THEN if_bali_constants=>c_severity_warning
                       WHEN 'S'               THEN if_bali_constants=>c_severity_status
                       ELSE                        if_bali_constants=>c_severity_information ).
    TRY.
        log->add_item( cl_bali_message_setter=>create( severity   = severity
                                                       id         = sy-msgid
                                                       number     = sy-msgno
                                                       variable_1 = sy-msgv1
                                                       variable_2 = sy-msgv2
                                                       variable_3 = sy-msgv3
                                                       variable_4 = sy-msgv4 ) ).
      CATCH cx_bali_runtime ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD save_log.
    " Second DB connection: the log is committed on its own - independent of the
    " job's COMMIT / ROLLBACK WORK, and it survives a dump in a later order
    CHECK log IS BOUND.
    TRY.
        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
            log                        = log
            assign_to_current_appl_job = attach_to_job ).
      CATCH cx_bali_runtime INTO DATA(bali_error).
        " Make problems with the log visible instead of losing them
        APPEND |E: Application log not saved: { bali_error->get_text( ) }| TO texts.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
