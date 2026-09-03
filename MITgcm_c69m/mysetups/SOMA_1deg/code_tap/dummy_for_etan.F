#include "AUTODIFF_OPTIONS.h"

CBOP
C     !ROUTINE: DUMMY_FOR_ETAN
C     !INTERFACE:
#ifdef ALLOW_TAPENADE
      SUBROUTINE DUMMY_FOR_ETAN(
     I     etaN,
     I     myTime, myIter, myThid )
#else
      SUBROUTINE DUMMY_FOR_ETAN( myTime, myIter, myThid )
#endif

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE DUMMY_FOR_ETAN                                |
C     *==========================================================*
C     Under Tapenade (ALLOW_TAPENADE) the interface also carries
C     the fields listed above. Tapenade has no equivalent of TAF's
C     ADNAME/REQUIRED directives: it emits the reverse-sweep call
C     DUMMY_FOR_ETAN_B only if active data crosses the interface.
C     The external-library stanza (tools/TAP_support/flow_tap; here
C     code_tap/flow_tap_local) declares those arguments read-then-
C     written, and the hand-written DUMMY_FOR_ETAN_B in
C     pkg/tapenade/dummy_tap.F is the adjoint body. This routine stays a
C     no-op and must never appear in an *_ad_diff.list. TAF and
C     OpenAD compile the unchanged three-argument interface.
C     \ev

C     !USES:
      IMPLICIT NONE

C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     myTime :: time counter for this thread
C     myIter :: iteration counter for this thread
C     myThid :: Thread number for this instance of the routine.
#ifdef ALLOW_TAPENADE
C     the free-surface height whose adjoint DUMMY_FOR_ETAN_B dumps as ADJetan
      _RL etaN   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
#endif /* ALLOW_TAPENADE */
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

C     !LOCAL VARIABLES:
CEOP

      RETURN
      END
