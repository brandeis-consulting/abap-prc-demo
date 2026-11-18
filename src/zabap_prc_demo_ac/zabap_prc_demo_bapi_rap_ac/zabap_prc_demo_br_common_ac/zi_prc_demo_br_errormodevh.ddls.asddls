@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP: Error mode value help'
@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZI_PRC_DEMO_BR_ErrorModeVH
  as select from ZI_PRC_DomainValues( p_domain_name: 'ZPRC_DEMO_BR_ERROR_MODE')
{
      @ObjectModel.text.element: [ 'Text' ]
  key Value as ErrorMode,
      @Semantics.text: true
      Text
}
