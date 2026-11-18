@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 1: Order (action)'
@Metadata.allowExtensions: true
define root view entity ZC_PRC_DEMO_BR_Action
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_BR_Action
{
  key OrderUUID,
      Description,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRC_DEMO_BR_ErrorModeVH', element: 'ErrorMode' } }]
      @ObjectModel.text.element: [ 'ErrorModeText' ]
      ErrorMode,
      _ErrorMode.Text as ErrorModeText,
      Status,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
