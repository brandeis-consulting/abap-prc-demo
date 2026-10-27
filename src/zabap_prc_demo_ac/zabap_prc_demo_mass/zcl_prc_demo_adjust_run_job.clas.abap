"! <p class="shorttext synchronized">Job for Adjustment Run</p>
"!
"! Run pattern: selects the service contracts to adjust; the run, creating the
"! processed objects and processing them is done by ZCL_PRC_RUN_JOB.
CLASS zcl_prc_demo_adjust_run_job DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_run_job FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.

    CONSTANTS: BEGIN OF c_parameter,
                 contract_id        TYPE zif_prc_run=>ty_run_parameter VALUE 'S_CTR',
                 sold_to_party      TYPE zif_prc_run=>ty_run_parameter VALUE 'S_SOLD',
                 ship_to_party      TYPE zif_prc_run=>ty_run_parameter VALUE 'S_SHIP',
                 lifecycle_status   TYPE zif_prc_run=>ty_run_parameter VALUE 'S_LIFE',
                 error_status       TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ERR',

                 equipment_category TYPE zif_prc_run=>ty_run_parameter VALUE 'P_EQCAT',
                 material           TYPE zif_prc_run=>ty_run_parameter VALUE 'P_MAT',
                 discount_percent   TYPE zif_prc_run=>ty_run_parameter VALUE 'P_DISC',
               END OF c_parameter.

    CONSTANTS: co_job_template_names TYPE zif_prc_run=>ty_job_template_name VALUE 'ZAJT_PRC_DEMO_ADJUST_RUN'.
    CONSTANTS: co_application_names  TYPE zprc_run_app_name VALUE 'DEMO_RATE_ADJUSTMENT'.

  PROTECTED SECTION.
    METHODS get_application_name REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS select               REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_prc_demo_adjust_run_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
        changeable_ind = abap_true
        ( selname = c_parameter-contract_id         kind = if_apj_dt_exec_object=>select_option datatype = 'C' length = 10 param_text = 'Service Contract' )
        ( selname = c_parameter-sold_to_party       kind = if_apj_dt_exec_object=>select_option datatype = 'C' length = 10 param_text = 'Sold-to-Party' )
        ( selname        = c_parameter-ship_to_party
          kind           = if_apj_dt_exec_object=>select_option
          component_type = 'ZPRC_DEMO_LIFECYCLE_STATUS'
          datatype       = 'C'
          length         = 10
          param_text     = 'Ship-to-Party' )
        ( selname        = c_parameter-lifecycle_status
          kind           = if_apj_dt_exec_object=>select_option
          component_type = 'ZPRC_DEMO_ERROR_STATUS'
          datatype       = 'C'
          length         = 1
          param_text     = 'Lifecycle Status' )
        ( selname = c_parameter-error_status        kind = if_apj_dt_exec_object=>select_option datatype = 'C' length = 1  param_text = 'Error Status' )

        ( selname        = c_parameter-equipment_category
          kind           = if_apj_dt_exec_object=>parameter
          datatype       = 'C'
          length         = 10
          param_text     = 'Equipment Category' )
        ( selname = c_parameter-material            kind = if_apj_dt_exec_object=>parameter datatype = 'C'   length = 10 param_text = 'Service' )
        ( selname = c_parameter-discount_percent    kind = if_apj_dt_exec_object=>parameter datatype = 'P'   length = 10 param_text = 'Discount (in %)' )
        ( selname = zif_prc_run=>co_parameter-p_uuid kind = if_apj_dt_exec_object=>parameter datatype = 'C'   length = 32 param_text = 'Run UUID' ) ).
  ENDMETHOD.


  METHOD select.
    " Ranges typed like the fields they select
    DATA contracts        TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ServiceContractID.
    DATA sold_to_parties  TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-SoldToPartyID.
    DATA ship_to_parties  TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ShipToPartyID.
    DATA lifecycle_states TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-LifecycleStatus.
    DATA error_states     TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ErrorStatus.

    get_range( EXPORTING i_select_options = i_select_options i_name = c_parameter-contract_id      IMPORTING e_range = contracts ).
    get_range( EXPORTING i_select_options = i_select_options i_name = c_parameter-sold_to_party    IMPORTING e_range = sold_to_parties ).
    get_range( EXPORTING i_select_options = i_select_options i_name = c_parameter-ship_to_party    IMPORTING e_range = ship_to_parties ).
    get_range( EXPORTING i_select_options = i_select_options i_name = c_parameter-lifecycle_status IMPORTING e_range = lifecycle_states ).
    get_range( EXPORTING i_select_options = i_select_options i_name = c_parameter-error_status     IMPORTING e_range = error_states ).

    SELECT DISTINCT ServiceContractID, ContractUUID
      FROM ZI_PRC_Demo_SrvCtrItemSel
      WHERE ServiceContractID IN @contracts
        AND SoldToPartyID     IN @sold_to_parties
        AND ShipToPartyID     IN @ship_to_parties
        AND LifecycleStatus   IN @lifecycle_states
        AND ErrorStatus       IN @error_states
      INTO TABLE @DATA(selected).

    r_objects = VALUE #( FOR s IN selected ( id   = s-ServiceContractID
                                             uuid = s-ContractUUID ) ).
  ENDMETHOD.


  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_demo_adj_run_proc=>co_process_name
                         factory_class = zcl_prc_demo_adj_run_proc=>co_class_name ).
  ENDMETHOD.


  METHOD get_application_name.
    rv_application_name = zif_prc_run=>co_application_names-demo_rate_adjustment.
  ENDMETHOD.

ENDCLASS.
