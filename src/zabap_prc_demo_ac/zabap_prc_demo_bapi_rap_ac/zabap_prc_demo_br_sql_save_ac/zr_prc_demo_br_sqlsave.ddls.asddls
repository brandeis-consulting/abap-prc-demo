@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 5: Order (ABAP SQL in save)'
define root view entity ZR_PRC_DEMO_BR_SqlSave
  as select from zprc_demo_brq
{
  key order_uuid            as OrderUUID,
      description           as Description,
      @Semantics.amount.currencyCode: 'Currency'
      amount                as Amount,
      currency              as Currency,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt
}
