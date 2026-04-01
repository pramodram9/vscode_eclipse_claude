@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Consumption (Projection) View'
@Metadata.allowExtensions: true
/*
 * Consumption (projection) CDS view for Sales Order.
 * This is the entity exposed via the service definition and consumed
 * by Fiori Elements apps and OData V4 clients.
 *
 * provider contract transactional_query — marks as draft-enabled
 * transactional projection (required for Fiori Elements LR+OP).
 *
 * Value Help annotations bind look-up entities to fields so that
 * Fiori Elements renders value-help dialogs automatically.
 */
@Search.searchable: true
define root view entity ZSOMGMT_C_SalesOrder
  provider contract transactional_query
  as projection on ZSOMGMT_I_SalesOrder
{
  key SalesOrderId,

      @Search.defaultSearchElement: true
      Description,

      /* Customer value help — resolves CustomerName automatically */
      @Consumption.valueHelpDefinition: [{
        entity: {
          name:    'I_BusinessPartner',
          element: 'BusinessPartner'
        },
        additionalBinding: [{
          localElement: 'CustomerName',
          element:      'BusinessPartnerName',
          usage:        #RESULT
        }]
      }]
      CustomerId,

      CustomerName,
      OrderDate,
      DeliveryDate,
      OverallStatus,
      OverallStatusCriticality,

      /* Currency value help — ISO currency codes */
      @Consumption.valueHelpDefinition: [{
        entity: {
          name:    'I_Currency',
          element: 'Currency'
        }
      }]
      Currency,

      @Semantics.amount.currencyCode: 'Currency'
      GrossAmount,

      @Semantics.amount.currencyCode: 'Currency'
      NetAmount,

      @Semantics.amount.currencyCode: 'Currency'
      TaxAmount,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,

      /* Redirect composition to consumption child projection */
      _Item : redirected to composition child ZSOMGMT_C_SalesOrderItem
}
