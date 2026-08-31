C--   These common blocks are extracted from the
C--   automatically created tangent linear code.
C--   You need to make sure that they are up-to-date
C--   (i.e. in right order), and customize them accordingly.
C--
C--   heimbach@mit.edu 11-Jan-2001

#ifdef ALLOW_AUTODIFF_MONITOR

      COMMON /DYNVARS_R_b/
     &                     EtaNb,
     &                     Uvelb, Vvelb, Wvelb,
     &                     Thetab, Saltb,
     &                     Gub, Gvb,
#ifdef ALLOW_ADAMSBASHFORTH_3
     &                     GuNmb, GvNmb, GtNmb, GsNmb
#else
     &                     GuNm1b, GvNm1b, GtNm1b, GsNm1b
#endif
      _RL EtaNb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL Gub(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Gvb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Saltb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Thetab(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Uvelb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Vvelb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Wvelb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#ifdef ALLOW_ADAMSBASHFORTH_3
      _RL GtNmb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy,2)
      _RL GsNmb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy,2)
      _RL GuNmb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy,2)
      _RL GvNmb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy,2)
#else
      _RL GtNm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL GsNm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL GuNm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL GvNm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif

      COMMON /DYNVARS_R_2_b/
     &                     EtaHb
      _RL EtaHb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)

#ifdef ALLOW_DIFFKR_CONTROL
      COMMON /DYNVARS_DIFFKR_b/
     &                       DiffKrb
      _RL  DiffKrb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif

#ifdef ALLOW_CD_CODE
      COMMON /DYNVARS_CD_b/
     &                      UvelDb, VvelDb,
     &                      EtaNm1b,
     &                      Unm1b, Vnm1b
      _RL UvelDb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL VvelDb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL EtaNm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL Unm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL Vnm1b(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif

      COMMON /FFIELDS_fu_b/ Fub
      COMMON /FFIELDS_fv_b/ Fvb
      COMMON /FFIELDS_Qnet_b/ Qnetb
      COMMON /FFIELDS_Qsw_b/ Qswb
      COMMON /FFIELDS_EmPmR_b/ EmPmRb
      COMMON /FFIELDS_saltFlux_b/ SaltFluxb
      COMMON /FFIELDS_SST_b/ SSTb
      COMMON /FFIELDS_SSS_b/ SSSb
      COMMON /FFIELDS_lambdaThetaClimRelax_b/ LambdaThetaClimRelaxb
      COMMON /FFIELDS_lambdaSaltClimRelax_b/ LambdaSaltClimRelaxb
      _RS  Fub       (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  Fvb       (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  Qnetb     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  Qswb      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  EmPmRb    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  SaltFluxb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  SSTb      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  SSSb      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  LambdaThetaClimRelaxb
     &    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS  LambdaSaltClimRelaxb
     &    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)

#ifdef ALLOW_KAPGM_CONTROL
      COMMON /GM_INP_K3D_GM_b/
     &                       KapGMb
      _RL  KapGMb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif
#ifdef ALLOW_KAPREDI_CONTROL
      COMMON /GM_INP_K3D_REDI_b/
     &                       KapRedib
      _RL  KapRedib (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif
#ifdef ALLOW_BOTTOMDRAG_CONTROL
      COMMON /CTRL_FIELDS_BOTTOMDRAG_b/
     &                BottomDragFldb
      _RL  BottomDragFldb (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
#endif


#endif /* ALLOW_AUTODIFF_MONITOR */
