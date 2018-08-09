USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCallerVerification]    Script Date: 04/16/2014 15:33:47 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCallerVerification]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCallerVerification]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCallerVerification]    Script Date: 04/16/2014 15:33:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




  
CREATE proc [dbo].[spRptCallerVerification]  
@OperatorID int,  
@StartDate smalldatetime,  
@EndDate smalldatetime,
@Session int

as  
--=============================================================================
 -- 2012.05.23 BSB: DE10386 - changed sessionid to session
 -- 2012.06.05 jkn: DE10456 changed the order of the parameters so the report
 -- would launch.
 -- 2012.07.10 jkn: DE10540 fixed issue with the wrong device type and and 
 -- serial number being returned
 -- 2013.05.16 tmp: DE10948 return the client identifier if the serial number is null.
 -- 2014.04.16 tmp: DE10948 fixed issue with Traveler and Tracker device type and serial number not being returned.
--=============================================================================

select pgwd.pgwdDateVerified  as [Date/ Time Verified],  
--date stay the same will modify it on crysatal report  
    pgwd.pgwdCardNo as [Card Number],  
    CASE WHEN pgw.pgwPermID = 1 THEN 'Electronic'
        WHEN pgw.pgwMachineID <> 0 THEN 'Electronic'
        WHEN pgw.pgwUnitNumber <> 0 THEN 'Electronic'
        ELSE 'Paper'  end as [Card Type],
    case when  pgw.pgwCardLevel  = 0 then ''
    else pgw.pgwCardLevel end as [Level],
    cl.LevelName as [Level Name],
    p.PermName as [Perm Name],
    cs.csCardStatus as [Card Status],
	Case when pgw.pgwUnitNumber <> 0 Then (Select Top 1 ul.ulUnitSerialNumber From UnLockLog ul Where ul.ulUnitNumber = pgw.pgwUnitNumber) -- DE10948
		 ELSE Isnull(m.SerialNumber, m.ClientIdentifier) End as [Device Serial Number],  
    sgpp.PatternName as [Pattern],  
    Case when pgw.pgwUnitNumber <> 0 Then (Select d.DeviceType From Device d where d.DeviceID = (Select Top 1 ul.ulDeviceID From UnLockLog ul where ul.ulUnitNumber = pgw.pgwUnitNumber)) -- DE10948
		 Else d.DeviceType End as [Device Type],  
    sp.GamingSession as [Session],  
    sp.GamingDate as [Gaming Date],  
    sgp.DTStart as [Game Start Time],  
    convert(varchar(20),sp.SessionStartDT,101)+ ' '+convert(varchar(20),sp.SessionStartDT,108)+ ' ' +right(convert(varchar(30),sp.SessionStartDT,109),2)as [Session Start Time],  
    convert(varchar(20),sp.SessionEndDT,101)+ ' '+convert(varchar(20),sp.SessionEndDT,108)+ ' ' +right(convert(varchar(30),sp.SessionEndDT,109),2) as [Session End Time],  
    sgp.DisplayGameNo as [Game Number],  
    sgp.GCName as [Game Name],  
    sgp.DisplayPartNo as [Part Number],  
    sp.OperatorID as [OperatorID]  
from ProgramGameWinnersDetail pgwd --a
    join SessionGamesPlayed sgp/*b*/ on sgp.SessionGamesPlayedID = pgwd.pgwdSessionGamesPlayedID  --15635  
    join CardStatus cs /*c*/ on cs.csCardStatusID = pgwd.pgwdCardStatus   
    join SessionPlayed sp /*d*/ on sp.SessionPlayedID = sgp.SessionPlayedID   
    join SessionGamesPlayedPattern sgpp /*f*/ on sgpp.SessionGamesPlayedID = sgp.SessionGamesPlayedID   
    join ProgramGameWinners pgw /*h*/ on (pgwd.pgwdSessionGamesPlayedID = pgw.pgwSessionGamesPlayedID   
        and pgwd.pgwdMasterCardNo = pgw.pgwMasterCardNo   
        and pgwd.pgwdPermID = pgw.pgwPermID)
    left join Machine m /*e*/ on m.MachineID = pgw.pgwMachineID
    left join Device d /*g*/ on d.DeviceID = m.DeviceID --15635
    left join CardLevel cl on cl.CardLevelID = pgw.pgwCardLevel 
    left join Perm p on p.PermID = pgwd.pgwdPermID
where (sp.OperatorID = @OperatorID or @OperatorID = 0)  
    and (sp.GamingSession = @Session or @Session = 0)   
    and sp.GamingDate >= @StartDate   
    and sp.GamingDate <= @EndDate   
order by pgwd.pgwdDateVerified asc  
  





















GO

