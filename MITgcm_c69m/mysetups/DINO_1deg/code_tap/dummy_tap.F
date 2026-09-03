#include "CPP_EEOPTIONS.h"
#include "AUTODIFF_OPTIONS.h"
#ifdef ALLOW_CTRL
# include "CTRL_OPTIONS.h"
#endif
#include "AD_CONFIG.h"

C--  File dummy_tap.F: hand-written Tapenade adjoints of the hooks that
C--  pkg/autodiff calls from the time step. Upstream ships the four
C--  dummy-hook routines below as no-op stubs; this shadow gives them
C--  bodies and adds the two mode-switch hooks' adjoints.
C--  Each _B argument list must match the call Tapenade generates
C--  (value/adjoint pairs, passives last); the build script counts the
C--  arguments of every generated call after make.
C--   Contents
C--   o  DUMMY_IN_STEPPING_B  (ADJ* dumps; halo-folds the adjoint fields first)
C--   o  DUMMY_IN_STEPPING_D  (no-op, so `make tap_tlm` links)
C--   o  DUMMY_FOR_ETAN_B     (ADJetan dump)
C--   o  DUMMY_FOR_ETAN_D     (no-op)
C--   o  AUTODIFF_INADMODE_SET_B   (enter adjoint mode: calls ADAUTODIFF_INADMODE_SET)
C--   o  AUTODIFF_INADMODE_SET_D   (no-op)
C--   o  AUTODIFF_INADMODE_UNSET_B (leave adjoint mode: calls ADAUTODIFF_INADMODE_UNSET)
C--   o  AUTODIFF_INADMODE_UNSET_D (no-op)

CBOP
C     !ROUTINE: DUMMY_IN_STEPPING_B
C     !INTERFACE:
      SUBROUTINE DUMMY_IN_STEPPING_B(
     I     theta, thetab, salt, saltb, uVel, uVelb,
     I     vVel, vVelb, wVel, wVelb,
     I     fu, fub, fv, fvb, Qnet, Qnetb, Qsw, Qswb,
     I     EmPmR, EmPmRb, diffKr, diffKrb,
     I     myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE DUMMY_IN_STEPPING_B                       |
C     *==========================================================*
C     Reverse-sweep body of DUMMY_IN_STEPPING: fold the tile
C     halos of the adjoint fields and dump them as ADJ* files.
C     Tapenade generates the call in the adjoint of FORWARD_STEP
C     because flow_tap (here code_tap/flow_tap_local) declares the hook's field
C     arguments active; the *b arguments alias the adjoint common
C     blocks, so the ADEXCH folds act on the live adjoint state
C     exactly as TAF's ADDUMMY_IN_STEPPING (pkg/autodiff/addummy_in_stepping.F) does.
C     The body mirrors ADDUMMY_IN_STEPPING restricted to the fields
C     the hook carries; packages this setup cannot enable through
C     the hook (SHELFICE, EddyPsi, depth control, MNC output, ...)
C     have no *b argument to read and are therefore absent here,
C     not removed from upstream.
C     The argument list MUST match the call Tapenade generates in
C     forward_step_b.f (value/adjoint pairs, passives last); the
C     build script verifies the argument count after every build.
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
# ifdef ALLOW_DIAGNOSTICS
#  include "DIAGNOSTICS_P2SHARE.h"
# endif
#endif /* ALLOW_AUTODIFF_MONITOR */

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     <fld>   :: primal field at this point of the reverse sweep (unused)
C     <fld>b  :: adjoint of <fld>; halo-folded and dumped here
C     myTime  :: time counter for this thread
C     myIter  :: iteration counter for this thread
C     myThid  :: Thread number for this instance of the routine.
      _RL theta  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL thetab (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL salt   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL saltb  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVelb  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vVelb  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wVelb  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RS fu     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fub    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fv     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fvb    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qnet   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qnetb  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qsw    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qswb   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS EmPmR  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS EmPmRb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL diffKr (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL diffKrb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

#if (defined (ALLOW_ADJOINT_RUN) || defined (ALLOW_ADMTLM))
#ifdef ALLOW_AUTODIFF_MONITOR

C     !FUNCTIONS:
      LOGICAL  DIFFERENT_MULTIPLE
      EXTERNAL DIFFERENT_MULTIPLE

C     !LOCAL VARIABLES:
      _RS dumRS(1)
      _RL dumRL(1)
      LOGICAL doExch
      LOGICAL doDump
CEOP

C--- Do dump?
      doDump = DIFFERENT_MULTIPLE( adjDumpFreq, myTime, deltaTClock )

C--- Test for adexch based on dumpAdVarExch flag
      doExch = doDump
#ifdef ALLOW_DIAGNOSTICS
      doExch = doDump .OR. useDiag4AdjOutp
#endif
      doExch = doExch .AND. ( dumpAdVarExch.EQ.1 )

C--- If necessary, do the exchanges
      IF ( doExch ) THEN
#ifndef ALLOW_BULK_OFFLINE
        CALL ADEXCH_3D_RL( thetab, Nr, myThid )
        CALL ADEXCH_3D_RL( saltb,  Nr, myThid )
        CALL ADEXCH_3D_RL( wVelb,  Nr, myThid )
        CALL ADEXCH_UV_3D_RL( uVelb, vVelb, .TRUE., Nr, myThid )
#endif
#ifndef AUTODIFF_EXCLUDE_ADEXCH_RS
        CALL ADEXCH_UV_XY_RS( fub, fvb, .TRUE., myThid )
        CALL ADEXCH_XY_RS( Qnetb, myThid )
        CALL ADEXCH_XY_RS( EmPmRb, myThid )
#endif
#ifdef ALLOW_DIFFKR_CONTROL
        CALL ADEXCH_3D_RL( diffKrb, Nr, myThid )
#endif
      ENDIF

C=======================================================================
C--  Dump AD-variable to binary files and fill diagnostics
C=======================================================================
      IF ( doDump ) THEN
C     Increment ad dump record number (used only if dumpAdByRec is true)
        dumpAdRecMn = dumpAdRecMn + 1
        CALL TIMER_START('I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

C-----------------------------------------------------------------------
C--- State variables
C-----------------------------------------------------------------------
      CALL DUMP_ADJ_XYZ(dumRS, thetab, 'ADJtheta', 'ADJtheta.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ(dumRS, saltb, 'ADJsalt ', 'ADJsalt.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ(dumRS, wVelb, 'ADJwvel ', 'ADJwvel.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ_UV(
     &     dumRS, uVelb, 'ADJuvel ', 'ADJuvel.',
     &     dumRS, vVelb, 'ADJvvel ', 'ADJvvel.',
     &     34, doDump, dumpAdRecMn, myTime, myIter,myThid)

C-----------------------------------------------------------------------
C--- Surface Forcing
C-----------------------------------------------------------------------
      IF ( .NOT. useSEAICE .AND. .NOT. useEXF ) THEN
       CALL DUMP_ADJ_XY_UV(
     &      fub, dumRL, 'ADJtaux ', 'ADJtaux.',
     &      fvb, dumRL, 'ADJtauy ', 'ADJtauy.',
     &      33, doDump, dumpAdRecMn, myTime, myIter,myThid)
        CALL DUMP_ADJ_XY(Qnetb, dumRL, 'ADJqnet ', 'ADJqnet.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)
        CALL DUMP_ADJ_XY(EmPmRb, dumRL, 'ADJempmr', 'ADJempmr.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)

#ifdef SHORTWAVE_HEATING
        CALL DUMP_ADJ_XY(Qswb, dumRL, 'ADJqsw  ', 'ADJqsw.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)
#endif
      ENDIF

C-----------------------------------------------------------------------
C---Various packages and parameters
C-----------------------------------------------------------------------
#ifdef ALLOW_DIFFKR_CONTROL
      CALL DUMP_ADJ_XYZ(dumRS, diffKrb, 'ADJdifkr', 'ADJdiffkr.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)
#endif

      IF ( doDump ) THEN
        CALL TIMER_STOP( 'I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

#endif /* ALLOW_AUTODIFF_MONITOR */
#endif /* ALLOW_ADJOINT_RUN */

      RETURN
      END

CBOP
C     !ROUTINE: DUMMY_IN_STEPPING_D
C     !INTERFACE:
      SUBROUTINE DUMMY_IN_STEPPING_D(
     I     theta, thetad, salt, saltd, uVel, uVeld,
     I     vVel, vVeld, wVel, wVeld,
     I     fu, fud, fv, fvd, Qnet, Qnetd, Qsw, Qswd,
     I     EmPmR, EmPmRd, diffKr, diffKrd,
     I     myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     Tangent-linear counterpart, kept as a no-op so `make tap_tlm`
C     links. Never exercised here (DINO builds no TLM); verify this
C     argument list against the generated the_main_loop_d.f call
C     before first real TLM use.
C     \ev

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
      _RL theta  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL thetad (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL salt   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL saltd  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL uVeld  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vVeld  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wVel   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wVeld  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RS fu     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fud    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fv     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS fvd    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qnet   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qnetd  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qsw    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS Qswd   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS EmPmR  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS EmPmRd (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL diffKr (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL diffKrd(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END

CBOP
C     !ROUTINE: DUMMY_FOR_ETAN_B
C     !INTERFACE:
      SUBROUTINE DUMMY_FOR_ETAN_B( etaN, etaNb,
     I                                 myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE DUMMY_FOR_ETAN_B                          |
C     *==========================================================*
C     Reverse-sweep body of DUMMY_FOR_ETAN: dump the adjoint
C     of the free-surface height as ADJetan.  Tapenade generates
C     the call in the adjoint of INTEGR_CONTINUITY because
C     flow_tap (here code_tap/flow_tap_local) declares etaN active; etaNb aliases
C     the adjoint common block, so this reads the live adjoint
C     state exactly as TAF's ADDUMMY_FOR_ETAN (pkg/autodiff/addummy_for_etan.F) reads adetan.
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
C     !ROUTINE: DUMMY_FOR_ETAN_D
C     !INTERFACE:
      SUBROUTINE DUMMY_FOR_ETAN_D( etaN, etaNd,
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

CBOP
C     !ROUTINE: AUTODIFF_INADMODE_UNSET_B
C     !INTERFACE:
      SUBROUTINE AUTODIFF_INADMODE_UNSET_B( uVel, uVelb,
     I                                 myTime, myIter, myThid )
C     !DESCRIPTION:
C     Reverse-sweep body of the Tapenade mode-switch hook
C     AUTODIFF_INADMODE_UNSET (called at the START of FORWARD_STEP, so
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
      SUBROUTINE AUTODIFF_INADMODE_UNSET_D( uVel, uVeld,
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
C     !ROUTINE: AUTODIFF_INADMODE_SET_B
C     !INTERFACE:
      SUBROUTINE AUTODIFF_INADMODE_SET_B( uVel, uVelb,
     I                               myTime, myIter, myThid )
C     !DESCRIPTION:
C     Reverse-sweep body of the Tapenade mode-switch hook
C     AUTODIFF_INADMODE_SET (called at the END of FORWARD_STEP, so this
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
      SUBROUTINE AUTODIFF_INADMODE_SET_D( uVel, uVeld,
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
