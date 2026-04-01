@EndUserText.label: 'Reject Order - Action Parameter Entity'
/*
 * Abstract entity used as the parameter type for the rejectOrder action.
 * Declared in the BDEF as:
 *   action rejectOrder parameter ZSOMGMT_A_RejectParam result [1] $self;
 *
 * The caller (Fiori Elements) renders a dialog for the user to enter
 * RejectionReason before the action is dispatched to the backend.
 */
define abstract entity ZSOMGMT_A_RejectParam
{
  @EndUserText.label: 'Rejection Reason'
  RejectionReason : abap.char( 256 );
}
