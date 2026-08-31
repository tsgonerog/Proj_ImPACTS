#include "AUTODIFF_OPTIONS.h"
#ifdef ALLOW_CTRL
# include "CTRL_OPTIONS.h"
#endif

C     Body identical to pkg/autodiff/autodiff_inadmode_unset_ad.F (c69m);
C     the ALLOW_TAPENADE wrapper at the end is what this shadow adds.

      SUBROUTINE ADAUTODIFF_INADMODE_UNSET( myTime, myIter, myThid )
C     *==========================================================*
C     | SUBROUTINE ADAUTODIFF_INADMODE_UNSET
C     *==========================================================*

C     !USES:
      IMPLICIT NONE
C     == Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "AUTODIFF_PARAMS.h"
#ifdef ALLOW_SEAICE
#include "SEAICE_SIZE.h"
#include "SEAICE_PARAMS.h"
#endif
#ifdef ALLOW_CTRL
# include "CTRL_SIZE.h"
# include "CTRL.h"
#endif
#ifdef ALLOW_AUTODIFF_MONITOR
# ifdef ALLOW_DIAGNOSTICS
#  include "DIAGNOSTICS_P2SHARE.h"
# endif
#endif /* ALLOW_AUTODIFF_MONITOR */

C     !INPUT/OUTPUT PARAMETERS:
C     myTime    :: Current time in simulation
C     myIter    :: Current iteration number
C     myThid    :: my Thread Id number
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

C     !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf

#ifdef ALLOW_AUTODIFF_MONITOR
# ifdef ALLOW_DIAGNOSTICS
      LOGICAL modelEnd
C --- Write the fields out here
      IF ( useDiag4AdjOutp ) THEN
C --- Grab modelEnd, necessary input for diagnostics routines
       modelEnd = myTime.EQ.startTime .OR. myIter.EQ.nIter0
       CALL TIMER_START('I/O (WRITE)        [ADJOINT LOOP]', myThid )
       CALL DIAGNOSTICS_WRITE_ADJ( modelEnd, myTime, myIter, myThid )
       CALL TIMER_STOP( 'I/O (WRITE)        [ADJOINT LOOP]', myThid )
      ENDIF
# endif /* ALLOW_DIAGNOSTICS */
#endif /* ALLOW_AUTODIFF_MONITOR */

      inAdMode  = .FALSE.

      useKPP    = useKPPinFwdMode
      useGMRedi = useGMRediInFwdMode
      useSEAICE = useSEAICEinFwdMode
      useGGL90    = useGGL90inFwdMode
      useSALT_PLUME    = useSALT_PLUMEinFwdMode
#ifdef ALLOW_SEAICE
      IF ( SEAICEuseFREEDRIFTswitchInAd ) THEN
        SEAICEuseFREEDRIFT = SEAICEuseFREEDRIFTinFwdMode
        SEAICEuseLSR       = .NOT.SEAICEuseFREEDRIFT
      ENDIF
      IF ( SEAICEuseDYNAMICSswitchInAd ) THEN
        SEAICEuseDYNAMICS  = SEAICEuseDYNAMICSinFwdMode
      ENDIF
      SEAICEadjMODE=0
C     SIregFacInFw = UNSET_RL by default, so we need to check this here
      IF ( SIregFacInFw .NE. UNSET_RL ) SINegFac = SIregFacInFw
#endif /* ALLOW_SEAICE */
      viscFacAdj=viscFacInFw

      IF ( debugLevel.GE.debLevC ) THEN
       WRITE(msgBuf,'(A,L5)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: useKPP    =', useKPP
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,L5)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: useGMRedi =', useGMRedi
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,L5)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: useSEAICE =', useSEAICE
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,L5)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: useGGL90    =', useGGL90
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,L5)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: useSALT_PLUME    =',
     &      useSALT_PLUME
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )

       WRITE(msgBuf,'(A,1PE21.14)')
     &      'S/R ADAUTODIFF_INADMODE_UNSET: viscFacAdj =',viscFacAdj
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )

#ifdef ALLOW_SEAICE
       IF ( SEAICEuseFREEDRIFTswitchInAd ) THEN
         WRITE(msgBuf,'(2A,L5)') 'S/R ADAUTODIFF_INADMODE_UNSET: ',
     &        'SEAICEuseFREEDRIFT =', SEAICEuseFREEDRIFT
         CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
         WRITE(msgBuf,'(2A,L5)') 'S/R ADAUTODIFF_INADMODE_UNSET: ',
     &        'SEAICEuseLSR       =', SEAICEuseLSR
         CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
       ENDIF
       IF ( SEAICEuseDYNAMICSswitchInAd ) THEN
         WRITE(msgBuf,'(2A,L5)') 'S/R ADAUTODIFF_INADMODE_UNSET: ',
     &        'SEAICEuseDYNAMICS =', SEAICEuseDYNAMICS
         CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
       ENDIF
       IF ( SEAICEapproxLevInAd.NE.0 ) THEN
         WRITE(msgBuf,'(2A,I2)') 'S/R ADAUTODIFF_INADMODE_UNSET: ',
     &        'SEAICEadjMODE =', SEAICEadjMODE
         CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
       ENDIF
#endif /* ALLOW_SEAICE */

      ENDIF

      RETURN
      END

#ifdef ALLOW_TAPENADE
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
#endif /* ALLOW_TAPENADE */
