@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Equipment'
@Metadata.allowExtensions: true
@Search.searchable: true

// Semantic key: navigation from other apps (service contract items) opens the object page
@ObjectModel.semanticKey: [ 'Identifier' ]

define root view entity ZC_PRC_DEMO_Equipment
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_Equipment
{
  key Identifier,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_PRC_DEMO_EquipmentCategory', element: 'Identifier' } } ]
      EquipmentCategory,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _EquipmentCategory
}
