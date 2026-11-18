@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP: Legacy document (C1)'
// Read access to the legacy documents for ABAP Cloud (released with contract C1).
// Written only by the BAPIs - via ZCL_PRC_DEMO_BR_BAPI_WRAP.
define view entity ZI_PRC_DEMO_BR_LegacyDoc
  as select from zprc_demo_br_leg
{
  key order_id              as OrderID,
      ref_order_uuid        as RefOrderUUID,
      description           as Description,
      error_mode            as ErrorMode,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_at       as LastChangedAt
}
