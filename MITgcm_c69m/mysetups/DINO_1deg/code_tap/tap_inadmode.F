#include "AUTODIFF_OPTIONS.h"

CBOP
C     !ROUTINE: TAP_INADMODE_UNSET
C     !INTERFACE:
      SUBROUTINE TAP_INADMODE_UNSET( uVel, myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_INADMODE_UNSET                            |
C     *==========================================================*
C     Tapenade-specific variant of AUTODIFF_INADMODE_UNSET: a no-op
C     hook called at the START of FORWARD_STEP. uVel is passed only
C     so code_tap/flow_tap_local can declare the call active, which
C     makes Tapenade generate CALL TAP_INADMODE_UNSET_B(...) at the
C     END of each backward step of forward_step_b - where adjoint-
C     mode parameters must revert to forward-mode values before the
C     next checkpoint re-forward. The _B body lives in the staged
C     autodiff_inadmode_unset_ad.F variant. This routine must stay
C     a no-op and must never appear in any *_ad_diff.list.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END

CBOP
C     !ROUTINE: TAP_INADMODE_SET
C     !INTERFACE:
      SUBROUTINE TAP_INADMODE_SET( uVel, myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_INADMODE_SET                              |
C     *==========================================================*
C     Tapenade-specific variant of AUTODIFF_INADMODE_SET: a no-op
C     hook called at the END of FORWARD_STEP, so its generated
C     CALL TAP_INADMODE_SET_B(...) runs at the START of each
C     backward step of forward_step_b - where the inAd* parameters
C     (the adjViscBoost machinery) must engage. The _B body lives
C     in the staged autodiff_inadmode_set_ad.F variant. Same rules
C     as TAP_INADMODE_UNSET above.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END
