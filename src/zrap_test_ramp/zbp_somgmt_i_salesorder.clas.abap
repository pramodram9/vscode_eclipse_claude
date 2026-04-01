"! <p class="shorttext synchronized" lang="en">Behavior Implementation – ZSOMGMT_I_SalesOrder</p>
"!
"! RAP managed behavior implementation class for the Sales Order BO.
"! Referenced in the behavior definition:
"!   managed implementation in class zbp_somgmt_i_salesorder unique;
"!
"! This global class shell is intentionally empty.
"! All handler logic lives in the CCIMP include (locals_imp):
"!   - lhc_salesorder      : validations, determinations, actions for header
"!   - lhc_salesorderitem  : validations and determinations for items
"!   - lsc_zsomgmt_i_salesorder : saver class (optional finalize hook)
CLASS zbp_somgmt_i_salesorder DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zsomgmt_i_salesorder.
ENDCLASS.

CLASS zbp_somgmt_i_salesorder IMPLEMENTATION.
ENDCLASS.
