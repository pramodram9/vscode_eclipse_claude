@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Tracker - Interface (Root BO) View'
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory:   #S,
  dataClass:      #TRANSACTIONAL
}
@ObjectModel.semanticKey: ['LeaveId']
/*
 * Root interface CDS view entity for the Leave Tracker BO.
 * This is the BO layer — never exposed directly to consumers.
 * Projection view ZLVTRK_C_Leave is the consumer-facing entity.
 *
 * Key design points:
 *  - Single entity, no compositions (fully self-contained).
 *  - @Semantics annotations drive automatic admin-field population by
 *    the RAP managed framework (CreatedBy, CreatedAt, etc.).
 *  - StatusCriticality is a computed field used by UI annotations
 *    to colourize the status badge:
 *      N (New)      = 0 → Grey   (neutral)
 *      A (Approved) = 3 → Green  (positive)
 *      R (Rejected) = 1 → Red    (negative)
 */
define root view entity ZLVTRK_I_Leave
  as select from zlvtrk_d_leave
{
  key leave_id                                       as LeaveId,

      employee_name                                  as EmployeeName,
      leave_type                                     as LeaveCategory,
      start_date                                     as StartDate,
      end_date                                       as EndDate,
      num_days                                       as NumDays,
      reason                                         as Reason,
      status                                         as Status,

      /* Status criticality for UI colour coding */
      case status
        when 'A' then 3   -- positive / green
        when 'R' then 1   -- negative / red
        else          0   -- neutral  / grey (N=New or initial)
      end                                            as StatusCriticality,

      @Semantics.user.createdBy:               true
      created_by                                     as CreatedBy,

      @Semantics.systemDateTime.createdAt:     true
      created_at                                     as CreatedAt,

      @Semantics.user.lastChangedBy:           true
      last_changed_by                                as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                                as LastChangedAt
}
