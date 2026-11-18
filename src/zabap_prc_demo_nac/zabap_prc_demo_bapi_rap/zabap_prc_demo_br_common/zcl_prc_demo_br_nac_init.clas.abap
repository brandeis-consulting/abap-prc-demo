"! <p class="shorttext synchronized">BAPI &amp; RAP: Reset of the Standard ABAP scenarios (C1)</p>
"!
"! Demo only. Scenarios 2 and 3 are Standard ABAP (BAPI test run in a validation),
"! so their tables cannot be reset from the ABAP Cloud init class directly.
"! Released with contract C1 and called by ZCL_PRC_DEMO_BR_INIT. No COMMIT WORK.
CLASS zcl_prc_demo_br_nac_init DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Deletes the orders and drafts of scenario 3 and the drafts of scenario 2
    CLASS-METHODS reset.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_br_nac_init IMPLEMENTATION.

  METHOD reset.
    DELETE FROM zprc_demo_brp_d.     " scenario 2: drafts (the documents belong to the BAPI)
    DELETE FROM zprc_demo_brs.       " scenario 3: orders
    DELETE FROM zprc_demo_brs_d.     " scenario 3: drafts
  ENDMETHOD.

ENDCLASS.
