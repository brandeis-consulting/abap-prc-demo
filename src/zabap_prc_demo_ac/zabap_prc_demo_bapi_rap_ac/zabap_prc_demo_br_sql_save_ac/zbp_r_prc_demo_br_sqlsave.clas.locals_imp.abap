CLASS lhc_demoorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DemoOrder RESULT result.
ENDCLASS.


CLASS lhc_demoorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

ENDCLASS.


"! Direct database changes are allowed in the late save (SAVE_MODIFIED) -
"! not in the interaction phase and not in FINALIZE / CHECK_BEFORE_SAVE.
CLASS lsc_zr_prc_demo_br_sqlsave DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_zr_prc_demo_br_sqlsave IMPLEMENTATION.

  METHOD save_modified.
    " MAPPING FROM ENTITY uses the BDEF mapping (CDS names -> table columns)
    IF create-demoorder IS NOT INITIAL.
      INSERT zprc_demo_brq FROM TABLE @create-demoorder MAPPING FROM ENTITY.
    ENDIF.

    " ABAP SQL UPDATE writes ALL columns. This is only correct because the BDEF
    " declares "with full data": UPDATE-DEMOORDER contains every field, not only
    " the changed ones. Without it, unchanged columns would be cleared.
    " (Alternative without full data: UPDATE ... INDICATORS SET STRUCTURE %control.)
    IF update-demoorder IS NOT INITIAL.
      UPDATE zprc_demo_brq FROM TABLE @update-demoorder MAPPING FROM ENTITY.
    ENDIF.

    " The delete table of the saver is not accepted by ABAP SQL directly:
    " convert it into a derived type FOR DELETE first
    IF delete-demoorder IS NOT INITIAL.
      DATA deleted TYPE TABLE FOR DELETE zr_prc_demo_br_sqlsave.
      deleted = CORRESPONDING #( delete-demoorder ).
      DELETE zprc_demo_brq FROM TABLE @deleted MAPPING FROM ENTITY.
    ENDIF.
    " No COMMIT WORK - RAP commits
  ENDMETHOD.

ENDCLASS.
