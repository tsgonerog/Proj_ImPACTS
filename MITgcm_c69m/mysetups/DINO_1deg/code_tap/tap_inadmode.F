#include "AUTODIFF_OPTIONS.h"

C     The two Tapenade mode-switch hooks that code_tap/forward_step.F
C     calls, and their hand-written adjoints, all in this one file:
C
C       TAP_INADMODE_UNSET    forward no-op, called at the START of
C                             FORWARD_STEP
C       TAP_INADMODE_UNSET_B  its reverse-sweep body, hence run at the END
C                             of each backward step: leave adjoint mode
C                             (calls ADAUTODIFF_INADMODE_UNSET)
C       TAP_INADMODE_SET      forward no-op, called at the END of
C                             FORWARD_STEP
C       TAP_INADMODE_SET_B    its reverse-sweep body, hence run at the
C                             START of each backward step: enter adjoint
C                             mode (calls ADAUTODIFF_INADMODE_SET)
C
C     plus no-op _D counterparts so `make tap_tlm` links. uVel is only the
C     activity vehicle: code_tap/flow_tap_local declares it read-then-
C     written, which is what makes Tapenade generate the _B calls at all;
C     the _B bodies must leave uVelb untouched (identity adjoint). Each _B
C     argument list must match the generated call in forward_step_b.f;
C     the build scripts assert it (check_gen_call).
C
C     The TAF-named bodies the _B routines call are the vendored
C     pkg/autodiff/autodiff_inadmode_{set,unset}_ad.F in a plain build, or
C     the code_tap/variants/adjViscBoost/ shadows (inAd*/outAd* overrides)
C     when build_tapAdj_adjViscBoost.sh lists that directory first in
C     -mods. The forward no-ops must stay no-ops, and this file must never
C     appear in any *_ad_diff.list.

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
C     next checkpoint re-forward. The _B body is TAP_INADMODE_UNSET_B
C     below. This routine must stay a no-op.
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
C     !ROUTINE: TAP_INADMODE_UNSET_B
C     !INTERFACE:
      SUBROUTINE TAP_INADMODE_UNSET_B( uVel, uVelb,
     I                                 myTime, myIter, myThid )
C     !DESCRIPTION:
C     Reverse-sweep body of the Tapenade mode-switch hook
C     TAP_INADMODE_UNSET (called at the START of FORWARD_STEP, so
C     this runs at the END of each backward step): leave adjoint
C     mode, restoring forward-mode parameters for the next
C     checkpoint re-forward. uVel is only the activity vehicle that
C     makes Tapenade generate this call (declared read-then-written
C     in flow_tap_local); uVelb must be left untouched (identity
C     adjoint). The argument list must match the generated call in
C     forward_step_b.f; the build script asserts it.
C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
C     !INPUT/OUTPUT PARAMETERS:
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVelb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP
      CALL ADAUTODIFF_INADMODE_UNSET( myTime, myIter, myThid )
      RETURN
      END

C     No-op tangent-linear counterpart so `make tap_tlm` links; verify
C     the argument list against the generated call before first TLM use.
      SUBROUTINE TAP_INADMODE_UNSET_D( uVel, uVeld,
     I                                 myTime, myIter, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVeld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
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
C     (the adjViscBoost machinery) must engage. The _B body is
C     TAP_INADMODE_SET_B below. Same rules as TAP_INADMODE_UNSET.
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
C     !ROUTINE: TAP_INADMODE_SET_B
C     !INTERFACE:
      SUBROUTINE TAP_INADMODE_SET_B( uVel, uVelb,
     I                               myTime, myIter, myThid )
C     !DESCRIPTION:
C     Reverse-sweep body of the Tapenade mode-switch hook
C     TAP_INADMODE_SET (called at the END of FORWARD_STEP, so this
C     runs at the START of each backward step): enter adjoint mode.
C     uVel is only the activity vehicle that makes Tapenade generate
C     this call (declared read-then-written in flow_tap_local); uVelb
C     must be left untouched (identity adjoint). The argument list
C     must match the generated call in forward_step_b.f; the build
C     script asserts it.
C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
C     !INPUT/OUTPUT PARAMETERS:
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVelb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP
      CALL ADAUTODIFF_INADMODE_SET( myTime, myIter, myThid )
      RETURN
      END

C     No-op tangent-linear counterpart so `make tap_tlm` links; verify
C     the argument list against the generated call before first TLM use.
      SUBROUTINE TAP_INADMODE_SET_D( uVel, uVeld,
     I                               myTime, myIter, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVeld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
      RETURN
      END
