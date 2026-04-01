@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Interface (Root BO) View'
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory:   #M,
  dataClass:      #TRANSACTIONAL
}
/*
 * Root interface CDS view entity for the Sales Order Management BO.
 * This is the BO layer — never exposed directly to consumers.
 * Projection view ZSOMGMT_C_SalesOrder is the consumer-facing entity.
 *
 * Key design points:
 *  - Composition to child entity ZSOMGMT_I_SalesOrderItem (_Item)
 *  - @Semantics annotations drive automatic admin-field population by
 *    the RAP managed framework (CreatedBy, CreatedAt, etc.)
 *  - OverallStatusCriticality is a computed field used by UI annotations
 *    to colorise the status badge (0=grey 1=red 2=yellow 3=green)
 */
define root view entity ZSOMGMT_I_SalesOrder
  as select from zsomgmt_d_so_hdr
  composition [0..*] of ZSOMGMT_I_SalesOrderItem as _Item
{
  key salesorderid                               as SalesOrderId,

      description                                as Description,
      customerid                                 as CustomerId,
      customername                               as CustomerName,
      orderdate                                  as OrderDate,
      deliverydate                               as DeliveryDate,
      overallstatus                              as OverallStatus,

      /* Status criticality for UI colour coding */
      case overallstatus
        when 'A' then 3   -- success / green
        when 'P' then 2   -- warning / yellow
        when 'X' then 1   -- error   / red
        else          0   -- neutral / grey
      end                                        as OverallStatusCriticality,

      @Semantics.currencyCode: true
      currency                                   as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      grossamount                                as GrossAmount,

      @Semantics.amount.currencyCode: 'Currency'
      netamount                                  as NetAmount,

      @Semantics.amount.currencyCode: 'Currency'
      taxamount                                  as TaxAmount,

      @Semantics.user.createdBy:                  true
      createdby                                  as CreatedBy,

      @Semantics.systemDateTime.createdAt:        true
      createdat                                  as CreatedAt,

      @Semantics.user.lastChangedBy:              true
      lastchangedby                              as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt:    true
      lastchangedat                              as LastChangedAt,

      /* Expose composition association for child entity navigation */
      _Item
}
