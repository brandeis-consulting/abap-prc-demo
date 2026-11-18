@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 2: Legacy document'
@Metadata.allowExtensions: true
define root view entity ZC_PRC_DEMO_BR_Persist
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_BR_Persist
{
  key OrderID,
      Description,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRC_DEMO_BR_ErrorModeVH', element: 'ErrorMode' } }]
      @ObjectModel.text.element: [ 'ErrorModeText' ]
      ErrorMode,
      _ErrorMode.Text as ErrorModeText,
      LocalLastChangedAt,
      LastChangedAt
}
