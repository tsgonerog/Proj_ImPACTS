#include "AUTODIFF_OPTIONS.h"

CBOP
C     !ROUTINE: TAP_DUMMY_FOR_ETAN
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_FOR_ETAN( etaN, myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_DUMMY_FOR_ETAN                            |
C     *==========================================================*
C     Tapenade-specific variant of DUMMY_FOR_ETAN: a no-op hook
C     called from INTEGR_CONTINUITY under ALLOW_AUTODIFF_MONITOR.
C     Unlike TAF, Tapenade only inserts a reverse-sweep call for a
C     routine whose interface carries active data, so etaN is passed
C     as an argument and declared active in code_tap/flow_tap_local
C     (read-then-written). Tapenade then generates
C     CALL TAP_DUMMY_FOR_ETAN_B(...) in the adjoint of
C     INTEGR_CONTINUITY; the hand-written _B in addummy_for_etan.F
C     is where ADJetan is dumped. This routine must stay a no-op
C     and must never appear in any *_ad_diff.list.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     etaN   :: free-surface height, passed only to expose its
C               activity to Tapenade
C     myTime :: time counter for this thread
C     myIter :: iteration counter for this thread
C     myThid :: Thread number for this instance of the routine.
      _RL etaN  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END
