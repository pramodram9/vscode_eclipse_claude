@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Tracker - Interface View V1'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory: #S,
  dataClass: #TRANSACTIONAL
}
@ObjectModel.semanticKey: ['LeaveId']
define root view entity ZLVTRK_I_Leave_V1
  as select from zlvtrk_d_leave_v1
{
  key leave_id                        as LeaveId,

      employee_name                   as EmployeeName,

      //-- Rule 1: alias renamed from LeaveType → LeaveCategory
      //-- to avoid EDM entity type name collision (expose...as Leave → LeaveType)
      leave_type                      as LeaveCategory,

      start_date                      as StartDate,

      end_date                        as EndDate,

      num_days                        as NumDays,

      reason                          as Reason,

      status                          as Status,

      //-- Computed criticality: N=0 (grey), A=3 (green), R=1 (red)
      case status
        when 'A' then cast( 3 as abap.int4 )
        when 'R' then cast( 1 as abap.int4 )
        else          cast( 0 as abap.int4 )
      end                             as StatusCriticality,

      @Semantics.user.createdBy: true
      created_by                      as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at                      as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by                 as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                 as LastChangedAt
}
