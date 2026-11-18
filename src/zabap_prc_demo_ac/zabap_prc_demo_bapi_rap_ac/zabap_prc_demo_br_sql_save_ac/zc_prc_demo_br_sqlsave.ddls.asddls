@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 5: Order (ABAP SQL in save)'
@Metadata.allowExtensions: true
define root view entity ZC_PRC_DEMO_BR_SqlSave
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_BR_SqlSave
{
  key OrderUUID,
      Description,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      Currency,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
