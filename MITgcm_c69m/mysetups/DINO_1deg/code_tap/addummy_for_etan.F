#include "AUTODIFF_OPTIONS.h"
#ifdef ALLOW_OPENAD
# include "OPENAD_OPTIONS.h"
#endif
#ifdef ALLOW_CTRL
# include "CTRL_OPTIONS.h"
#endif
#include "AD_CONFIG.h"

CBOP
C     !ROUTINE: ADDUMMY_FOR_ETAN
C     !INTERFACE:
      SUBROUTINE ADDUMMY_FOR_ETAN( myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE ADDUMMY_FOR_ETAN                              |
C     *==========================================================*
C     Extract adjoint variable for sea level height
C     from TAF-generated
C     adjoint common blocks, contained in adcommon.h
C     and write fields to file;
C     Make sure common blocks in adcommon.h are up-to-date
C     w.r.t. current adjoint code.
C
C     This dummy routine is located inside integr_continuity
C     to get the impact of rstar or surf_dr adjoint
C     variables on adEtaN.
C
C     This does not use the diagnostics package because adEtaN is a
C     "half" time step away from the other adjoint variables, but would
C     have to be written at the same time.
C
C     Created: Tim Smith, tsmith@ices.utexas.edu, Sept 12 2018
C     *==========================================================*
C     | SUBROUTINE ADDUMMY_FOR_ETAN                              |
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE

C     == Global variables ===
#ifdef ALLOW_OPENAD
      use OAD_active
      use OAD_rev
      use OAD_tape
      use OAD_cp
#endif
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#ifdef ALLOW_AUTODIFF_MONITOR
# ifdef ALLOW_OPENAD
#  include "DYNVARS.h"
# endif
# include "AUTODIFF_PARAMS.h"
# include "AUTODIFF.h"
# ifndef ALLOW_OPENAD
#  include "adcommon.h"
# endif /* ALLOW_OPENAD */
# ifdef ALLOW_MNC
#  include "MNC_PARAMS.h"
# endif
#endif /* ALLOW_AUTODIFF_MONITOR */

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     myTime  :: time counter for this thread
C     myIter  :: iteration counter for this thread
C     myThid  :: Thread number for this instance of the routine.
      _RL myTime
      INTEGER myIter
      INTEGER myThid

#if (defined (ALLOW_ADJOINT_RUN) || defined (ALLOW_ADMTLM))
#ifdef ALLOW_AUTODIFF_MONITOR

C     !FUNCTIONS:
      LOGICAL  DIFFERENT_MULTIPLE
      EXTERNAL DIFFERENT_MULTIPLE

C     !LOCAL VARIABLES:
C     == local variables ==
C     suff    :: Hold suffix part of a filename
C     msgBuf  :: Error message buffer
c     CHARACTER*(10) suff
c     CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RS dumRS(1)
      LOGICAL doDump
CEOP

      doDump = DIFFERENT_MULTIPLE(adjDumpFreq,myTime,deltaTClock)

      IF ( doDump ) THEN
C increment ad dump record number (used only if dumpAdByRec is true)
C could be just dumpAdRecEt=dumpAdRecMn+1 ????
       dumpAdRecEt = dumpAdRecEt + 1
       CALL TIMER_START('I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

#ifndef ALLOW_OPENAD
      CALL DUMP_ADJ_XY(dumRS, adetan, 'ADJetan ', 'ADJetan.',
     &                 12, doDump, dumpAdRecEt, myTime, myIter,myThid)
#else /* ndef ALLOW_OPENAD */
      CALL DUMP_ADJ_XY(dumRS, etaN%d, 'ADJetan ', 'ADJetan.',
     &                 12, doDump, dumpAdRecEt, myTime, myIter,myThid)
#endif /* ndef ALLOW_OPENAD */

      IF ( doDump ) THEN

C-- NOW NMC output
#ifndef ALLOW_OPENAD
#ifdef ALLOW_MNC
        IF ( useMNC .AND. autodiff_mnc ) THEN
         CALL MNC_CW_SET_UDIM('adstate', -1, myThid)
         CALL MNC_CW_RL_W_S('D','adstate',0,0,'T',myTime,myThid)
         CALL MNC_CW_SET_UDIM('adstate', 0, myThid)
         CALL MNC_CW_I_W_S('I','adstate',0,0,'iter',myIter,myThid)
         CALL MNC_CW_RL_W_S('D','adstate',0,0,'model_time',myTime,
     &        myThid)
         CALL MNC_CW_RL_W('D','adstate',0,0,'adEta', adEtaN, myThid)
C     endif mnc
        ENDIF
#endif /* ALLOW_MNC */
#endif /* ALLOW_OPENAD */

        CALL TIMER_STOP( 'I/O (WRITE)        [ADJOINT LOOP]', myThid )

      ENDIF

#endif /* ALLOW_AUTODIFF_MONITOR */
#endif /* ALLOW_ADJOINT_RUN */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef ALLOW_TAPENADE
C     Everything above is the unmodified upstream file; this block is the
C     only DINO addition.  Which adjoint body runs is decided by the AD
C     tool the build enables:
C       TAF      : ADDUMMY_FOR_ETAN (above) - inserted by the ADNAME
C                  directive in dummy_for_etan.flow, reads adetan from
C                  TAF's common blocks via adcommon.h.  Under a Tapenade
C                  build it still compiles, as dead code, just as it does
C                  in an upstream Tapenade verification build.
C       Tapenade : TAP_DUMMY_FOR_ETAN_B (below) - Tapenade-generated
C                  call; the adjoint of etaN arrives as an explicit
C                  argument, so adcommon.h is not needed.

CBOP
C     !ROUTINE: TAP_DUMMY_FOR_ETAN_B
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_FOR_ETAN_B( etaN, etaNb,
     I                                 myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_DUMMY_FOR_ETAN_B                          |
C     *==========================================================*
C     Reverse-sweep body of TAP_DUMMY_FOR_ETAN: dump the adjoint
C     of the free-surface height as ADJetan.  Tapenade generates
C     the call in the adjoint of INTEGR_CONTINUITY because
C     code_tap/flow_tap_local declares etaN active; etaNb aliases
C     the adjoint common block, so this reads the live adjoint
C     state exactly as TAF's ADDUMMY_FOR_ETAN (above) reads adetan.
C     Like upstream, no ADEXCH fold is applied before the dump.
C     etaNb must be left untouched (identity adjoint).
C     The argument list MUST match the call Tapenade generates in
C     integr_continuity_b.f; the build script verifies the argument
C     count after every build.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE

C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#ifdef ALLOW_AUTODIFF_MONITOR
# include "AUTODIFF_PARAMS.h"
# include "AUTODIFF.h"
# ifdef ALLOW_MNC
#  include "MNC_PARAMS.h"
# endif
#endif /* ALLOW_AUTODIFF_MONITOR */

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     etaN    :: primal field at this point of the reverse sweep (unused)
C     etaNb   :: adjoint of etaN; dumped here
C     myTime  :: time counter for this thread
C     myIter  :: iteration counter for this thread
C     myThid  :: Thread number for this instance of the routine.
      _RL etaN  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL etaNb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

#if (defined (ALLOW_ADJOINT_RUN) || defined (ALLOW_ADMTLM))
#ifdef ALLOW_AUTODIFF_MONITOR

C     !FUNCTIONS:
      LOGICAL  DIFFERENT_MULTIPLE
      EXTERNAL DIFFERENT_MULTIPLE

C     !LOCAL VARIABLES:
C     == local variables ==
      _RS dumRS(1)
      LOGICAL doDump
CEOP

      doDump = DIFFERENT_MULTIPLE(adjDumpFreq,myTime,deltaTClock)

      IF ( doDump ) THEN
C increment ad dump record number (used only if dumpAdByRec is true)
       dumpAdRecEt = dumpAdRecEt + 1
       CALL TIMER_START('I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

      CALL DUMP_ADJ_XY(dumRS, etaNb, 'ADJetan ', 'ADJetan.',
     &                 12, doDump, dumpAdRecEt, myTime, myIter,myThid)

      IF ( doDump ) THEN

C-- NOW NMC output
#ifdef ALLOW_MNC
        IF ( useMNC .AND. autodiff_mnc ) THEN
         CALL MNC_CW_SET_UDIM('adstate', -1, myThid)
         CALL MNC_CW_RL_W_S('D','adstate',0,0,'T',myTime,myThid)
         CALL MNC_CW_SET_UDIM('adstate', 0, myThid)
         CALL MNC_CW_I_W_S('I','adstate',0,0,'iter',myIter,myThid)
         CALL MNC_CW_RL_W_S('D','adstate',0,0,'model_time',myTime,
     &        myThid)
         CALL MNC_CW_RL_W('D','adstate',0,0,'adEta', etaNb, myThid)
C     endif mnc
        ENDIF
#endif /* ALLOW_MNC */

        CALL TIMER_STOP( 'I/O (WRITE)        [ADJOINT LOOP]', myThid )

      ENDIF

#endif /* ALLOW_AUTODIFF_MONITOR */
#endif /* ALLOW_ADJOINT_RUN */

      RETURN
      END

CBOP
C     !ROUTINE: TAP_DUMMY_FOR_ETAN_D
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_FOR_ETAN_D( etaN, etaNd,
     I                                 myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     Tangent-linear counterpart, kept as a no-op so `make tap_tlm`
C     links. Never exercised here (DINO builds no TLM); verify this
C     argument list against the generated call before first real
C     TLM use.
C     \ev

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
      _RL etaN  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL etaNd (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END
#endif /* ALLOW_TAPENADE */
