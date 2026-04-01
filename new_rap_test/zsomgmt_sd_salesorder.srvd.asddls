/*
 * Service Definition — ZSOMGMT_SD_SalesOrder
 *
 * Exposes the two projection entities as OData entity sets.
 * The service binding ZSOMGMT_SB_SalesOrder_V4 (created manually in ADT)
 * will reference this service definition and publish the OData V4 endpoint.
 *
 * Steps to publish in Eclipse ADT after importing via abapGit:
 *   1. Activate all dependent objects (tables → CDS views → BDEFs → class).
 *   2. Activate this service definition.
 *   3. Right-click → New → Other ABAP Repository Object
 *      → Business Services → Service Binding
 *      Name:     ZSOMGMT_SB_SALESORDER_V4
 *      Binding:  OData V4 - UI
 *      Service:  ZSOMGMT_SD_SalesOrder
 *   4. Click "Publish" in the service binding editor.
 *   5. The local service URL is shown — use it in Fiori Launchpad or Postman.
 *
 * Fiori Elements app generator (SAP Business Application Studio / BAS):
 *   Template   : List Report Object Page
 *   Data source: Connect to a System → pick your dev system
 *   Service    : ZSOMGMT_SD_SalesOrder
 *   Main entity: SalesOrder
 */
@EndUserText.label: 'Sales Order Management Service'
define service ZSOMGMT_SD_SalesOrder
{
  expose ZSOMGMT_C_SalesOrder     as SalesOrder;
  expose ZSOMGMT_C_SalesOrderItem as SalesOrderItem;
}
