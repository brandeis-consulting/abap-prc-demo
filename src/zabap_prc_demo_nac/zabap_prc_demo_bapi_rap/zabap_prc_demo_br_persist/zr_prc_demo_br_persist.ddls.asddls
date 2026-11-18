@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BAPI & RAP 2: Legacy document'
// Read via the released view - the legacy table belongs to the BAPI
define root view entity ZR_PRC_DEMO_BR_Persist
  as select from ZI_PRC_DEMO_BR_LegacyDoc
  association [0..1] to ZI_PRC_DEMO_BR_ErrorModeVH as _ErrorMode on $projection.ErrorMode = _ErrorMode.ErrorMode
{
  key OrderID,
      Description,
      ErrorMode,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      _ErrorMode
}
