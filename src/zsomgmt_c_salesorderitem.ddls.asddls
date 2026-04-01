@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item - Consumption (Projection) View'
@Metadata.allowExtensions: true
/*
 * Consumption (projection) CDS view for Sales Order line items.
 * Exposed within the service as a composition child of ZSOMGMT_C_SalesOrder.
 * Inline editing is supported in the Fiori Elements Object Page item table.
 */
define view entity ZSOMGMT_C_SalesOrderItem
  as projection on ZSOMGMT_I_SalesOrderItem
{
  key SalesOrderId,
  key ItemNumber,

      /* Product value help */
      @Consumption.valueHelpDefinition: [{
        entity: {
//          name:    'I_Product',
          element: 'Product'
        },
        additionalBinding: [{
          localElement: 'ProductDescription',
          element:      'ProductDescription',
          usage:        #RESULT
        }]
      }]
      ProductId,

      ProductDescription,
      Quantity,

      /* Unit of measure value help */
      @Consumption.valueHelpDefinition: [{
        entity: {
          name:    'I_UnitOfMeasure',
          element: 'UnitOfMeasure'
        }
      }]
      QuantityUnit,

      Currency,

      @Semantics.amount.currencyCode: 'Currency'
      UnitPrice,

      @Semantics.amount.currencyCode: 'Currency'
      NetAmount,

      ItemStatus,
      ItemStatusCriticality,

      /* Redirect parent association to consumption root */
      _SalesOrder : redirected to parent ZSOMGMT_C_SalesOrder
}
