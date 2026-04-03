@EndUserText.label: 'Leave Tracker - Consumption View V1'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZLVTRK_C_Leave_V1
  provider contract transactional_query
  as projection on ZLVTRK_I_Leave_V1
{
  key LeaveId,

      @Search.defaultSearchElement: true
      EmployeeName,

      LeaveCategory,
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
