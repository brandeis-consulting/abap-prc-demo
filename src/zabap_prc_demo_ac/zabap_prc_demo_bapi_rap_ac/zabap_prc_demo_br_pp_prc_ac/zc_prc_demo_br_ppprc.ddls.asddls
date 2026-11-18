@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 4: Order (post-proc. w. PRC)'
@Metadata.allowExtensions: true
define root view entity ZC_PRC_DEMO_BR_PpPrc
  provider contract transactional_query
  as projection on ZR_PRC_DEMO_BR_PpPrc
{
  key OrderUUID,
      Description,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRC_DEMO_BR_ErrorModeVH', element: 'ErrorMode' } }]
      @ObjectModel.text.element: [ 'ErrorModeText' ]
      ErrorMode,
      _ErrorMode.Text as ErrorModeText,

      // Latest PRC process of this order (list): state, message and its criticality
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PRC_DEMO_BR_PP_STATE'
      virtual ProcessState       : zprc_state,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PRC_DEMO_BR_PP_STATE'
      virtual ProcessMessage     : zprc_message_text,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PRC_DEMO_BR_PP_STATE'
      virtual ProcessCriticality : abap.int1,

      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // All PRC processes of this order (object page) - with the PRC's own annotations
      _ProcessedObject : redirected to ZC_PRC_ProcessedObject
}
