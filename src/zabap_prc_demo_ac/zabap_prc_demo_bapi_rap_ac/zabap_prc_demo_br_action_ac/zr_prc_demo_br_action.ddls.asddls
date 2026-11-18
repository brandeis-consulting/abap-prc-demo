@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 1: Order (action)'
define root view entity ZR_PRC_DEMO_BR_Action
  as select from zprc_demo_bra
  association [0..1] to ZI_PRC_DEMO_BR_ErrorModeVH as _ErrorMode on $projection.ErrorMode = _ErrorMode.ErrorMode
{
  key order_uuid            as OrderUUID,
      description           as Description,
      error_mode            as ErrorMode,
      status                as Status,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      _ErrorMode
}
