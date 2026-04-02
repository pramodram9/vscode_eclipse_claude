@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Tracker - Consumption (Projection) View'
@Metadata.allowExtensions: true
/*
 * Consumption (projection) CDS view for Leave Tracker.
 * This is the entity exposed via the service definition and consumed
 * by Fiori Elements apps and OData V4 clients.
 *
 * provider contract transactional_query — marks as draft-enabled
 * transactional projection (required for Fiori Elements LR+OP).
 *
 * No value-help associations are defined — fully self-contained
 * as required for BTP Cloud Trial (no standard table dependencies).
 */
@Search.searchable: true
define root view entity ZLVTRK_C_Leave
  provider contract transactional_query
  as projection on ZLVTRK_I_Leave
{
  key LeaveId,

      @Search.defaultSearchElement: true
      EmployeeName,

      LeaveType,
      StartDate,
      EndDate,
      NumDays,
      Reason,
      Status,
      StatusCriticality,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
