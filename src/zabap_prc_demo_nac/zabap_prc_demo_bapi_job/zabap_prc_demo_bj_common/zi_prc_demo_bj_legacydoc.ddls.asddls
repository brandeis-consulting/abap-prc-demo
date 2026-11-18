@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & Jobs: Legacy document (C1)'
// Read access to the legacy documents for ABAP Cloud (released with contract C1).
// Written only by the BAPIs - via ZCL_PRC_DEMO_BJ_BAPI_WRAP.
define view entity ZI_PRC_DEMO_BJ_LegacyDoc
  as select from zprc_demo_bj_leg
{
  key order_id       as OrderID,
      ref_order_uuid as RefOrderUUID,
      description    as Description
}
