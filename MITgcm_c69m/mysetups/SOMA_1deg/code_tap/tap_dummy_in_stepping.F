#include "AUTODIFF_OPTIONS.h"

CBOP
C     !ROUTINE: TAP_DUMMY_IN_STEPPING
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_IN_STEPPING(
     I     theta, salt, uVel, vVel, wVel,
     I     fu, fv, Qnet, Qsw, EmPmR, diffKr,
     I     myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_DUMMY_IN_STEPPING                         |
C     *==========================================================*
C     Tapenade-specific variant of DUMMY_IN_STEPPING: a no-op hook
C     called from FORWARD_STEP under ALLOW_AUTODIFF_MONITOR.
C     Unlike TAF, Tapenade only inserts a reverse-sweep call for a
C     routine whose interface carries active data, so the state and
C     forcing fields are passed as arguments and declared active in
C     code_tap/flow_tap_local (read-then-written). Tapenade then
C     generates CALL TAP_DUMMY_IN_STEPPING_B(...) in the adjoint of
C     FORWARD_STEP; the hand-written _B in addummy_in_stepping.F is
C     where the ADJ* fields are dumped. This routine must stay a
C     no-op and must never appear in any *_ad_diff.list.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     theta ... diffKr :: model state and forcing fields, passed only
C                         to expose their activity to Tapenade
C     myTime :: time counter for this thread
C     myIter :: iteration counter for this thread
C     myThid :: Thread number for this instance of the routine.
      _RL theta (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL salt  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wVel  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RS fu    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fv    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qnet  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qsw   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS EmPmR (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL diffKr(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END
