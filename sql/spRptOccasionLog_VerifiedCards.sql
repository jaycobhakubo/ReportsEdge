USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_VerifiedCards]    Script Date: 12/04/2012 14:42:31 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionLog_VerifiedCards]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionLog_VerifiedCards]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_VerifiedCards]    Script Date: 12/04/2012 14:42:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<FortuNet>
-- Create date: <11/29/2012>
-- Description:	<Listing of all card face number verified for each game.>
-- =============================================
CREATE PROCEDURE [dbo].[spRptOccasionLog_VerifiedCards]
	(
	@OperatorID Int,
	@StartDate DateTime,
	@Session Int
	)
AS
BEGIN
	
	SET NOCOUNT ON;
	
Declare @EndDate as DateTime
Set @EndDate = @StartDate

-- For testing
--Set @OperatorID = 1
--Set @StartDate = '04/04/2012'
--Set @Session = 1

Declare @Results Table
(
	GamingDate DateTime,
	GamingSession Int,
	GameNumber Int,
	PartNumber Int,
	Pattern Nvarchar(64),
	DateTimeVerified DateTime,
	CardNumber Int,
	PermName Nvarchar(32),
	LevelName Nvarchar(32),
	CardStatus varchar(50)
)
Insert @Results
(	
	GamingDate,
	GamingSession,
	GameNumber,
	PartNumber,
	Pattern,
	DateTimeVerified,
	CardNumber,
	PermName,
	LevelName,
	CardStatus
)
select sp.GamingDate,
	sp.GamingSession,
	sgp.DisplayGameNo,  
    sgp.DisplayPartNo,
    sgpp.PatternName,  
	pgwd.pgwdDateVerified,  
    pgwd.pgwdCardNo,  
    p.PermName,
    cl.LevelName,
    cs.csCardStatus  
from ProgramGameWinnersDetail pgwd --a
    join SessionGamesPlayed sgp/*b*/ on sgp.SessionGamesPlayedID = pgwd.pgwdSessionGamesPlayedID  --15635  
    join CardStatus cs /*c*/ on cs.csCardStatusID = pgwd.pgwdCardStatus   
    join SessionPlayed sp /*d*/ on sp.SessionPlayedID = sgp.SessionPlayedID   
    join SessionGamesPlayedPattern sgpp /*f*/ on sgpp.SessionGamesPlayedID = sgp.SessionGamesPlayedID   
    join ProgramGameWinners pgw /*h*/ on (pgwd.pgwdSessionGamesPlayedID = pgw.pgwSessionGamesPlayedID   
        and pgwd.pgwdMasterCardNo = pgw.pgwMasterCardNo   
        and pgwd.pgwdPermID = pgw.pgwPermID)
    left join CardLevel cl on cl.CardLevelID = pgw.pgwCardLevel 
    left join Perm p on p.PermID = pgwd.pgwdPermID   
where sp.OperatorID = @OperatorID 
	and sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and (sp.GamingSession = @Session or @Session = 0)   
Group By	sp.GamingDate, sp.GamingSession,
	sgp.DisplayGameNo,  
    sgp.DisplayPartNo,
    sgpp.PatternName,  
	pgwd.pgwdDateVerified,  
    pgwd.pgwdCardNo,  
    p.PermName,
    cl.LevelName,
    cs.csCardStatus  

Select *
From @Results

Set Nocount OFF

End  
GO


