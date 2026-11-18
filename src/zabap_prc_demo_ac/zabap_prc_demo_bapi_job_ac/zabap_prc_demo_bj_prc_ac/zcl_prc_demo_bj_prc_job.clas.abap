"! <p class="shorttext synchronized">BAPI &amp; Jobs: Application job with ABAP-PRC</p>
"!
"! Run pattern of ABAP-PRC: the job only selects the orders. Run, processed
"! objects, processing and closing the run are done by ZCL_PRC_RUN_JOB; the run
"! is monitored in the Run app. Same parameters as ZCL_PRC_DEMO_BJ_PLAIN_JOB.
CLASS zcl_prc_demo_bj_prc_job DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_run_job
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.

    CONSTANTS: BEGIN OF co_parameter,
                 order      TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ORDER',
                 error_mode TYPE zif_prc_run=>ty_run_parameter VALUE 'P_ERROR',
                 every_nth  TYPE zif_prc_run=>ty_run_parameter VALUE 'P_NTH',
               END OF co_parameter.
    CONSTANTS co_application_name TYPE zprc_run_app_name VALUE 'DEMO_BAPI_JOB'.

  PROTECTED SECTION.
    METHODS select               REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS get_application_name REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_bj_prc_job IMPLEMENTATION.

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
          datatype = 'I' length = 10 param_text = 'Error for every n-th order (default 3)' )
        ( selname = zif_prc_run=>co_parameter-p_uuid kind = if_apj_dt_exec_object=>parameter
          datatype = 'C' length = 32 param_text = 'Run UUID' ) ).
    et_parameter_val = VALUE #( ( selname = co_parameter-every_nth kind = if_apj_dt_exec_object=>parameter
                                  sign = 'I' option = 'EQ' low = '3' ) ).
  ENDMETHOD.


  METHOD select.
    DATA order_range TYPE RANGE OF zprc_demo_bjo-order_id.
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-order
               IMPORTING e_range          = order_range ).

    DATA(error_mode) = CONV zprc_demo_bj_error_mode(
                         VALUE #( i_parameter_values[ name = co_parameter-error_mode ]-value OPTIONAL ) ).
    DATA(every_nth)  = CONV i(
                         VALUE #( i_parameter_values[ name = co_parameter-every_nth ]-value DEFAULT `3` ) ).

    SELECT order_uuid, order_id FROM zprc_demo_bjo
      WHERE order_id IN @order_range
      ORDER BY order_id
      INTO TABLE @DATA(orders).

    " The provoked errors are job parameters - they travel in the payload.
    " Every n-th order by order number - the same orders as in the job without PRC.
    LOOP AT orders INTO DATA(order).
      DATA(number) = zcl_prc_demo_bj_bapi_util=>order_number( order-order_id ).
      APPEND VALUE #( id           = order-order_id
                      uuid         = order-order_uuid
                      payload_json = zcl_prc_demo_bj_proc=>to_payload( VALUE #(
                                       mode_a = zcl_prc_demo_bj_bapi_util=>error_mode_for(
                                                  i_bapi = 'A' i_error_mode = error_mode
                                                  i_order_number = number i_every_nth = every_nth )
                                       mode_b = zcl_prc_demo_bj_bapi_util=>error_mode_for(
                                                  i_bapi = 'B' i_error_mode = error_mode
                                                  i_order_number = number i_every_nth = every_nth ) ) ) )
             TO r_objects.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_demo_bj_proc=>co_process_name
                         factory_class = zcl_prc_demo_bj_proc=>co_class_name ).
  ENDMETHOD.


  METHOD get_application_name.
    r_application_name = co_application_name.
  ENDMETHOD.

ENDCLASS.
