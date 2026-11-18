@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 3: Order (post-proc. in save)'
@Metadata.allowExtensions: true
define root view entity ZC_PRC_DEMO_BR_PpSave
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_BR_PpSave
{
  key OrderUUID,
      Description,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRC_DEMO_BR_ErrorModeVH', element: 'ErrorMode' } }]
      @ObjectModel.text.element: [ 'ErrorModeText' ]
      ErrorMode,
      _ErrorMode.Text as ErrorModeText,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
