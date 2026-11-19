"! <p class="shorttext synchronized">Job for Adjustment Run</p>
"!
"! Run pattern: selects the service contracts to adjust; the run, creating the
"! processed objects and processing them is done by ZCL_PRC_RUN_JOB.
"!
"! The parameter P_SIM makes the run a simulation (IS_SIMULATION): set when the
"! job is scheduled directly, or passed by the service contract app.
CLASS zcl_prc_demo_adjust_run_job DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_run_job FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.

    "! Application of the runs (Runs app, authorization ZPRC_RUN-ZPRCRUNAPP)
    CONSTANTS co_application_name  TYPE zprc_run_app_name                 VALUE 'DEMO_RATE_ADJUSTMENT'.
    "! Job template that schedules this job
    CONSTANTS co_job_template_name TYPE zif_prc_run=>ty_job_template_name VALUE 'ZAJT_PRC_DEMO_ADJUST_RUN'.

    " Selection names of the job parameters. The values are stored in job templates
    " and scheduled jobs - do not change them.
    CONSTANTS: BEGIN OF co_parameter,
                 contract_id        TYPE zif_prc_run=>ty_run_parameter VALUE 'S_CTR',
                 sold_to_party      TYPE zif_prc_run=>ty_run_parameter VALUE 'S_SOLD',
                 ship_to_party      TYPE zif_prc_run=>ty_run_parameter VALUE 'S_SHIP',
                 lifecycle_status   TYPE zif_prc_run=>ty_run_parameter VALUE 'S_LIFE',
                 error_status       TYPE zif_prc_run=>ty_run_parameter VALUE 'S_ERR',

                 equipment_category TYPE zif_prc_run=>ty_run_parameter VALUE 'P_EQCAT',
                 material           TYPE zif_prc_run=>ty_run_parameter VALUE 'P_MAT',
                 discount_percent   TYPE zif_prc_run=>ty_run_parameter VALUE 'P_DISC',
                 simulation         TYPE zif_prc_run=>ty_run_parameter VALUE 'P_SIM',
               END OF co_parameter.

  PROTECTED SECTION.
    METHODS get_application_name REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS select               REDEFINITION.
    METHODS is_simulation        REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_prc_demo_adjust_run_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
        changeable_ind = abap_true
        ( selname    = co_parameter-contract_id
          kind       = if_apj_dt_exec_object=>select_option
          datatype   = 'C'
          length     = 10
          param_text = 'Service Contract' )
        ( selname    = co_parameter-sold_to_party
          kind       = if_apj_dt_exec_object=>select_option
          datatype   = 'C'
          length     = 10
          param_text = 'Sold-to-Party' )
        ( selname    = co_parameter-ship_to_party
          kind       = if_apj_dt_exec_object=>select_option
          datatype   = 'C'
          length     = 10
          param_text = 'Ship-to-Party' )
        ( selname        = co_parameter-lifecycle_status
          kind           = if_apj_dt_exec_object=>select_option
          component_type = 'ZPRC_DEMO_LIFECYCLE_STATUS'
          datatype       = 'C'
          length         = 1
          param_text     = 'Lifecycle Status' )
        ( selname        = co_parameter-error_status
          kind           = if_apj_dt_exec_object=>select_option
          component_type = 'ZPRC_DEMO_ERROR_STATUS'
          datatype       = 'C'
          length         = 1
          param_text     = 'Error Status' )

        ( selname    = co_parameter-equipment_category
          kind       = if_apj_dt_exec_object=>parameter
          datatype   = 'C'
          length     = 10
          param_text = 'Equipment Category' )
        ( selname    = co_parameter-material
          kind       = if_apj_dt_exec_object=>parameter
          datatype   = 'C'
          length     = 10
          param_text = 'Service' )
        ( selname    = co_parameter-discount_percent
          kind       = if_apj_dt_exec_object=>parameter
          datatype   = 'P'
          length     = 10
          param_text = 'Discount (in %)' )
        ( selname      = co_parameter-simulation
          kind         = if_apj_dt_exec_object=>parameter
          datatype     = 'C'
          length       = 1
          checkbox_ind = abap_true
          param_text   = 'Simulation' )
        ( selname    = zif_prc_run=>co_parameter-p_uuid
          kind       = if_apj_dt_exec_object=>parameter
          datatype   = 'C'
          length     = 32
          param_text = 'Run UUID' ) ).
  ENDMETHOD.


  METHOD select.
    " Ranges typed like the fields they select
    DATA contracts        TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ServiceContractID.
    DATA sold_to_parties  TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-SoldToPartyID.
    DATA ship_to_parties  TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ShipToPartyID.
    DATA lifecycle_states TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-LifecycleStatus.
    DATA error_states     TYPE RANGE OF ZI_PRC_Demo_SrvCtrItemSel-ErrorStatus.

    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-contract_id
               IMPORTING e_range          = contracts ).
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-sold_to_party
               IMPORTING e_range          = sold_to_parties ).
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-ship_to_party
               IMPORTING e_range          = ship_to_parties ).
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-lifecycle_status
               IMPORTING e_range          = lifecycle_states ).
    get_range( EXPORTING i_select_options = i_select_options
                         i_name           = co_parameter-error_status
               IMPORTING e_range          = error_states ).

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


  METHOD is_simulation.
    DATA(simulation) = VALUE #( i_parameter_values[ name = co_parameter-simulation ] OPTIONAL ).
    r_simulation = xsdbool( simulation-value = abap_true ).
  ENDMETHOD.


  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_demo_adj_run_proc=>co_process_name
                         factory_class = zcl_prc_demo_adj_run_proc=>co_class_name ).
  ENDMETHOD.


  METHOD get_application_name.
    r_application_name = co_application_name.
  ENDMETHOD.

ENDCLASS.
