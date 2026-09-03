#include "AUTODIFF_OPTIONS.h"

#ifdef ALLOW_TAPENADE
      SUBROUTINE AUTODIFF_INADMODE_SET(
     I     uVel,
     I     myTime, myIter, myThid )
#else
      SUBROUTINE AUTODIFF_INADMODE_SET( myTime, myIter, myThid )
#endif
C     *==========================================================*
C     | SUBROUTINE AUTODIFF_INADMODE_SET
C     *==========================================================*
C     Under Tapenade (ALLOW_TAPENADE) the interface also carries
C     uVel, an activity vehicle only. Tapenade has no equivalent of TAF's
C     ADNAME/REQUIRED directives: it emits the reverse-sweep call
C     AUTODIFF_INADMODE_SET_B only if active data crosses the interface.
C     The external-library stanza (tools/TAP_support/flow_tap; here
C     code_tap/flow_tap_local) declares those arguments read-then-
C     written, and the hand-written AUTODIFF_INADMODE_SET_B in
C     pkg/tapenade/dummy_tap.F is the adjoint body. This routine stays a
C     no-op and must never appear in an *_ad_diff.list. TAF and
C     OpenAD compile the unchanged three-argument interface.

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     myTime    :: Current time in simulation
C     myIter    :: Current iteration number
C     myThid    :: my Thread Id number
#ifdef ALLOW_TAPENADE
C     uVel is only the activity vehicle that makes Tapenade emit the _B call
      _RL uVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif /* ALLOW_TAPENADE */
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

      RETURN
      END
