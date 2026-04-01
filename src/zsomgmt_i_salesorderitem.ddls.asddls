@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item - Interface (Child BO) View'
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory:   #M,
  dataClass:      #TRANSACTIONAL
}
/*
 * Child interface CDS view entity for Sales Order line items.
 * Linked to parent via "association to parent" — the RAP framework uses
 * this to maintain the composition relationship and cascade draft / delete.
 *
 * ItemStatusCriticality drives colour coding on the item table in the UI.
 */
define view entity ZSOMGMT_I_SalesOrderItem
  as select from zsomgmt_d_so_itm

  /* Back-navigation to parent — required for composition child */
  association to parent ZSOMGMT_I_SalesOrder as _SalesOrder
    on $projection.SalesOrderId = _SalesOrder.SalesOrderId
{
  key salesorderid                               as SalesOrderId,
  key itemnumber                                 as ItemNumber,

      productid                                  as ProductId,
      productdescription                         as ProductDescription,

      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      quantity                                   as Quantity,

      uom                                        as QuantityUnit,

      currency                                   as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      unitprice                                  as UnitPrice,

      @Semantics.amount.currencyCode: 'Currency'
      netamount                                  as NetAmount,

      itemstatus                                 as ItemStatus,

      /* Item status criticality for UI colour coding */
      case itemstatus
        when 'D' then 3   -- delivered / green
        when 'C' then 1   -- cancelled / red
        else          0   -- new       / grey
      end                                        as ItemStatusCriticality,

      /* Back-pointer association exposed for parent navigation */
      _SalesOrder
}
