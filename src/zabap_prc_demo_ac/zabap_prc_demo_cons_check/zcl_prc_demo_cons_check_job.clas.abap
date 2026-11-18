"! <p class="shorttext synchronized">Demo: Consistency check run of unreleased contracts</p>
"!
"! Run pattern: selects all service contracts that are not released; the run,
"! creating the processed objects and processing them is done by
"! ZCL_PRC_RUN_JOB. A run always creates its own processed objects - another
"! run must not take over the objects of this one. Open checks of earlier runs
"! stay as they are; the Check action of a contract processes them again.
"!
"! Why a run: a contract can become inconsistent without being changed, when
"! another contract with the same equipment is released. Only a new check of
"! all unreleased contracts finds that.
CLASS zcl_prc_demo_cons_check_job DEFINITION
  PUBLIC
  INHERITING FROM zcl_prc_run_job FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apj_dt_exec_object~get_parameters REDEFINITION.

    "! Application of the runs (Runs app, authorization ZPRC_RUN-ZPRCRUNAPP)
    CONSTANTS co_application_name  TYPE zprc_run_app_name                 VALUE 'DEMO_CONS_CHECK'.
    "! Job template that schedules this job
    CONSTANTS co_job_template_name TYPE zif_prc_run=>ty_job_template_name VALUE 'ZAJT_PRC_DEMO_CONS_CHECK'.

  PROTECTED SECTION.
    METHODS get_application_name REDEFINITION.
    METHODS get_process          REDEFINITION.
    METHODS select               REDEFINITION.
ENDCLASS.


CLASS zcl_prc_demo_cons_check_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    " No selection: the run checks all unreleased contracts
    et_parameter_def = VALUE #( ( selname        = zif_prc_run=>co_parameter-p_uuid
                                  kind           = if_apj_dt_exec_object=>parameter
                                  datatype       = 'C'
                                  length         = 32
                                  param_text     = 'Run UUID'
                                  changeable_ind = abap_true ) ).
  ENDMETHOD.


  METHOD select.
    SELECT FROM zprc_demo_srvctr
      FIELDS service_contract_id, uuid
      WHERE lifecycle_status <> @zcl_prc_demo_cons_checker=>co_released
      INTO TABLE @DATA(contracts).

    r_objects = VALUE #( FOR c IN contracts ( id   = c-service_contract_id
                                              uuid = c-uuid ) ).
  ENDMETHOD.


  METHOD get_process.
    r_process = VALUE #( name          = zcl_prc_demo_cons_check_proc=>co_process_name
                         factory_class = zcl_prc_demo_cons_check_proc=>co_class_name ).
  ENDMETHOD.


  METHOD get_application_name.
    r_application_name = co_application_name.
  ENDMETHOD.

ENDCLASS.
