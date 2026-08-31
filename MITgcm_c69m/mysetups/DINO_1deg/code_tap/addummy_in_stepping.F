#include "AUTODIFF_OPTIONS.h"
#ifdef ALLOW_OPENAD
# include "OPENAD_OPTIONS.h"
#endif
#ifdef ALLOW_CTRL
# include "CTRL_OPTIONS.h"
#endif
#ifdef ALLOW_GMREDI
# include "GMREDI_OPTIONS.h"
#endif
#ifdef ALLOW_GGL90
# include "GGL90_OPTIONS.h"
#endif
#ifdef ALLOW_SHELFICE
# include "SHELFICE_OPTIONS.h"
#endif
#ifdef ALLOW_STEEP_ICECAVITY
# include "STIC_OPTIONS.h"
#endif
#include "AD_CONFIG.h"

C     One file, one hook, per-tool bodies. FORWARD_STEP calls the monitor
C     hook under ALLOW_AUTODIFF_MONITOR; which adjoint body runs is decided
C     by the AD tool the build enables:
C       TAF      : ADDUMMY_IN_STEPPING (below, #else branch) — inserted by
C                  the ADNAME directive in dummy_in_stepping.flow, reads the
C                  adjoint state from TAF's common blocks via adcommon.h.
C       Tapenade : TAP_DUMMY_IN_STEPPING_B (below) — generated call, the
C                  adjoint state arrives as explicit arguments, adcommon.h
C                  is not needed.

#ifdef ALLOW_TAPENADE

CBOP
C     !ROUTINE: TAP_DUMMY_IN_STEPPING_B
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_IN_STEPPING_B(
     I     theta, thetab, salt, saltb, uVel, uVelb,
     I     vVel, vVelb, wVel, wVelb,
     I     fu, fub, fv, fvb, Qnet, Qnetb, Qsw, Qswb,
     I     EmPmR, EmPmRb, diffKr, diffKrb,
     I     myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE TAP_DUMMY_IN_STEPPING_B                       |
C     *==========================================================*
C     Reverse-sweep body of TAP_DUMMY_IN_STEPPING: fold the tile
C     halos of the adjoint fields and dump them as ADJ* files.
C     Tapenade generates the call in the adjoint of FORWARD_STEP
C     because code_tap/flow_tap_local declares the hook's field
C     arguments active; the *b arguments alias the adjoint common
C     blocks, so the ADEXCH folds act on the live adjoint state
C     exactly as TAF's ADDUMMY_IN_STEPPING does.
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
C     !ROUTINE: TAP_DUMMY_IN_STEPPING_D
C     !INTERFACE:
      SUBROUTINE TAP_DUMMY_IN_STEPPING_D(
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

#else /* ALLOW_TAPENADE */

CBOP
C     !ROUTINE: ADDUMMY_IN_STEPPING
C     !INTERFACE:
      SUBROUTINE ADDUMMY_IN_STEPPING( myTime, myIter, myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE ADDUMMY_IN_STEPPING                           |
C     *==========================================================*
C     Extract adjoint variable from TAF-generated
C     adjoint common blocks, contained in adcommon.h
C     and write fields to file;
C     Make sure common blocks in adcommon.h are up-to-date
C     w.r.t. current adjoint code.
C     Condensed from pkg/autodiff/addummy_in_stepping.F (c69m):
C     MNC/OpenAD output paths and packages this setup never enables
C     (SEAICE, SHELFICE, EddyPsi, depth control, PTRACERS) omitted —
C     see the upstream file for the full version.
C     *==========================================================*
C     | SUBROUTINE ADDUMMY_IN_STEPPING                           |
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
C- Note: Since OpenAD uses modules, the ordering of included headers matters
#  include "DYNVARS.h"
#  include "FFIELDS.h"
#  ifdef ALLOW_GMREDI
#   include "GMREDI.h"
#  endif
#  ifdef ALLOW_GGL90
#   include "GGL90.h"
#  endif
# endif /* ALLOW_OPENAD */
# include "AUTODIFF_PARAMS.h"
# include "AUTODIFF.h"
# ifndef ALLOW_OPENAD
#  include "adcommon.h"
# endif /* ALLOW_OPENAD */
# ifdef ALLOW_MNC
#  include "MNC_PARAMS.h"
# endif
# ifdef ALLOW_DIAGNOSTICS
#  include "DIAGNOSTICS_P2SHARE.h"
# endif
#endif /* ALLOW_AUTODIFF_MONITOR */

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     myTime  :: time counter for this thread
C     myIter  :: iteration counter for this thread
C     myThid  :: Thread number for this instance of the routine.
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
C     suff    :: Hold suffix part of a filename
C     msgBuf  :: Error message buffer
c     CHARACTER*(10) suff
c     CHARACTER*(MAX_LEN_MBUF) msgBuf
#ifdef ALLOW_MNC
      _RL var2Du(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL var2Dv(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL var3Du(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL var3Dv(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif
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
#ifdef ALLOW_OPENAD
C--   need to all the correct OpenAD EXCH S/R ; left empty for now
#else /* ALLOW_OPENAD */

#ifdef AUTODIFF_TAMC_COMPATIBILITY
        call adexch_xyz_rl( myThid,adTheta)
        call adexch_xyz_rl( myThid,adSalt)
        call adexch_xyz_rl( myThid,adwVel )
        call adexch_uv_xyz_rl(  .true. ,myThid,aduVel,advVel )

        call adexch_uv_xy_rs( .true., myThid, adfu, adfv )
        call adexch_xy_rs( myThid,adqnet )
        call adexch_xy_rs( myThid,adempmr )
# ifdef ALLOW_EDDYPSI_CONTROL
        call adexch_uv_xyz_rs(  .true. ,myThid,adeddypsix,adeddypsiy )
# endif
# ifdef ALLOW_DIFFKR_CONTROL
        call adexch_xyz_rl( myThid,addiffkr )
# endif
# ifdef ALLOW_KAPGM_CONTROL
        call adexch_xyz_rl( myThid, adKapGM )
# endif
# ifdef ALLOW_KAPREDI_CONTROL
        call adexch_xyz_rl( myThid, adKapRedi )
# endif
# ifdef ALLOW_BOTTOMDRAG_CONTROL
        call adexch_xy_rl( myThid,adbottomdragfld)
# endif
# else /* ndfef AUTODIFF_TAMC_COMPATIBILITY */

#  ifndef ALLOW_BULK_OFFLINE
        CALL ADEXCH_3D_RL( adTheta,Nr, myThid )
        CALL ADEXCH_3D_RL( adSalt, Nr, myThid )
        CALL ADEXCH_3D_RL( adwVel, Nr, myThid )
        CALL ADEXCH_UV_3D_RL( aduVel,advVel, .TRUE., Nr, myThid )
#  endif
C     There are rare cases when adexch_uv_xy_rs and adexch_xy_rs are not
C     generated by TAF and then the following lines will lead to an
C     error in the link step, for example, when there are no 2D forcing
C     fields controls. We should have a cpp flag for that that is
C     automatically defined if any 2D forcing controls are defined. As a
C     hack we use an excluding cpp-flag that needs to be defined if this
C     problem occurs
#ifndef AUTODIFF_EXCLUDE_ADEXCH_RS
        CALL ADEXCH_UV_XY_RS( adFu, adFv, .TRUE., myThid )
        CALL ADEXCH_XY_RS( adQnet, myThid )
        CALL ADEXCH_XY_RS( adEmPmR, myThid )
#endif
# ifdef ALLOW_EDDYPSI_CONTROL
        CALL ADEXCH_UV_XYZ_RS( adEddyPsiX, adEddyPsiY, .TRUE., myThid )
# endif
# ifdef ALLOW_DIFFKR_CONTROL
        CALL ADEXCH_3D_RL( adDiffKr, Nr, myThid )
# endif
# ifdef ALLOW_KAPGM_CONTROL
        CALL ADEXCH_3D_RL( adKapGM, Nr, myThid )
# endif
# ifdef ALLOW_KAPREDI_CONTROL
        CALL ADEXCH_3D_RL( adKapRedi, Nr, myThid )
# endif
# ifdef ALLOW_BOTTOMDRAG_CONTROL
        CALL ADEXCH_3D_RL( adBottomDragFld, 1 , myThid )
# endif

#endif /* AUTODIFF_TAMC_COMPATIBILITY */
#endif /* ALLOW_OPENAD */
      ENDIF

C=======================================================================
C--  Dump AD-variable to binary files and fill diagnostics
C=======================================================================
      IF ( doDump ) THEN
C     Increment ad dump record number (used only if dumpAdByRec is true)
        dumpAdRecMn = dumpAdRecMn + 1
        CALL TIMER_START('I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

#ifndef ALLOW_OPENAD
C========================
C--  TAF AD-variables:
C========================
C-----------------------------------------------------------------------
C--- State variables
C-----------------------------------------------------------------------
      CALL DUMP_ADJ_XYZ(dumRS, adTheta, 'ADJtheta', 'ADJtheta.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ(dumRS, adSalt, 'ADJsalt ', 'ADJsalt.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ(dumRS, adWvel, 'ADJwvel ', 'ADJwvel.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)

      CALL DUMP_ADJ_XYZ_UV(
     &     dumRS, adUvel, 'ADJuvel ', 'ADJuvel.',
     &     dumRS, adVvel, 'ADJvvel ', 'ADJvvel.',
     &     34, doDump, dumpAdRecMn, myTime, myIter,myThid)

C-----------------------------------------------------------------------
C--- Surface Forcing
C-----------------------------------------------------------------------
      IF ( .NOT. useSEAICE .AND. .NOT. useEXF ) THEN
       CALL DUMP_ADJ_XY_UV(
     &      adFu, dumRL, 'ADJtaux ', 'ADJtaux.',
     &      adFv, dumRL, 'ADJtauy ', 'ADJtauy.',
     &      33, doDump, dumpAdRecMn, myTime, myIter,myThid)
        CALL DUMP_ADJ_XY(adQnet, dumRL, 'ADJqnet ', 'ADJqnet.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)
        CALL DUMP_ADJ_XY(adEmPmR, dumRL, 'ADJempmr', 'ADJempr.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)

# ifdef SHORTWAVE_HEATING
        CALL DUMP_ADJ_XY(adQsw, dumRL, 'ADJqsw  ', 'ADJqsw.',
     &                   11, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif
      ENDIF

C-----------------------------------------------------------------------
C---Various packages and parameters
C-----------------------------------------------------------------------
# ifdef ALLOW_BOTTOMDRAG_CONTROL
      CALL DUMP_ADJ_XY(dumRS, adBottomDragFld,
     &                 'ADJbtdrg','ADJbottomdrag.',
     &                 12, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif
# ifdef ALLOW_GGL90
      CALL DUMP_ADJ_XYZ(dumRS, adGGL90TKE, 'ADJtke90', 'ADJggl90tke.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif
# ifdef ALLOW_DIFFKR_CONTROL
      CALL DUMP_ADJ_XYZ(dumRS, adDiffKr, 'ADJdifkr', 'ADJdiffkr.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif
# ifdef ALLOW_KAPGM_CONTROL
      CALL DUMP_ADJ_XYZ(dumRS, adKapGM, 'ADJkapgm', 'ADJkapgm.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif
# ifdef ALLOW_KAPREDI_CONTROL
      CALL DUMP_ADJ_XYZ(dumRS, adKapRedi, 'ADJkapre', 'ADJkapredi.',
     &                  12, doDump, dumpAdRecMn, myTime, myIter,myThid)
# endif

#endif /* ALLOW_OPENAD */

C=======================================================================
      IF ( doDump ) THEN
        CALL TIMER_STOP( 'I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF

#endif /* ALLOW_AUTODIFF_MONITOR */
#endif /* ALLOW_ADJOINT_RUN */

      RETURN
      END

#endif /* ALLOW_TAPENADE */
