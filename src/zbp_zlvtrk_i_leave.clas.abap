"! <p class="shorttext synchronized" lang="en">Behavior Implementation – ZLVTRK_I_Leave</p>
"!
"! RAP managed behavior implementation class for the Leave Tracker BO.
"! Referenced in the behavior definition:
"!   managed implementation in class zbp_zlvtrk_i_leave unique;
"!
"! This global class shell is intentionally empty for v1.0.
"! All CRUD persistence (INSERT / UPDATE / DELETE on ZLVTRK_D_LEAVE)
"! and draft table management (ZLVTRK_D_LEAVE_D) are handled entirely
"! by the RAP managed framework — no custom save_modified needed.
"!
"! Admin fields (CreatedBy, CreatedAt, LastChangedBy, LastChangedAt)
"! are auto-populated via @Semantics annotations in ZLVTRK_I_Leave.
"!
"! Implemented in CCIMP (locals_imp):
"!   lhc_leave~earlynumbering_create : FOR NUMBERING — assigns LV* key before buffer
"!   lhc_leave~set_initial_status    : determination — default Status = 'N'
"!
"! Planned (future scope):
"!   lhc_leave~validateDates         : validation   — EndDate >= StartDate
"!   lhc_leave~validateNumDays       : validation   — NumDays > 0
"!   lhc_leave~validateStatus        : validation   — Status IN (N, A, R)
CLASS zbp_zlvtrk_i_leave DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zlvtrk_i_leave.
ENDCLASS.

CLASS zbp_zlvtrk_i_leave IMPLEMENTATION.
ENDCLASS.
