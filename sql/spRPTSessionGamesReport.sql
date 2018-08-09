USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionGamesReport]    Script Date: 12/10/2012 16:50:35 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionGamesReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionGamesReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionGamesReport]    Script Date: 12/10/2012 16:50:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptSessionGamesReport]
	@StartDate		AS	SmallDateTime,
	@EndDate		AS	SmallDateTime,
	@OperatorID		AS	Int,
	@Session		AS	Int
AS
/*
    2012.01.04 jkn: DE9855 - Merged DE9840 from 3.4.0.3 into 3.5 (Fixed issue with continuation games not reporting properly)
    2012.02.08 jkn - DE10065 Only load the first pattern of an elimination
    2012.12.10 tmp - Ball calls are not being returned from the History database.
*/
SET NOCOUNT ON

create table #tempRPT (
	CalledTime datetime, 
	BallCalled smallint, 
    BallCalledStatus smallint,
	DTStart datetime, 
	DTEnd datetime, 
	GameSeqNo int, 
	DisplayGameNo int, 
	DisplayPartNo nvarchar(64), 
	GameName nvarchar(64), 
	PatternName nvarchar(64), 
	CardFace nvarchar(200), --JLW 7-21-2009 - Changed from 100 to 200 to match database
	CardNumber int, 
	CreditPaid money, 
	CashPaid money,
	SessionPlayedID int, 
	SessionGamesPlayedID int,
	EliminationGame bit,
    IsContinued bit,    -- DE9840
	GamingDate smalldatetime, 
	GamingSession tinyint, 
	OperatorID int, 
	ProgramName nvarchar(64),
	OperatorName nvarchar(32),
	Address1 nvarchar(64),
	Address2 nvarchar(64),
	City nvarchar(32),
	OState nvarchar(32),
	Zip nvarchar(32),
	Country nvarchar(32)
)

-- Create a temp table to retrieve all of the games
declare @gameTable table
(
    DTStart datetime,
    DTEnd   datetime,
    GameSeqNo int,
    DisplayGameNo int,
    DisplayPartNo nvarchar(64),
    GameName nvarchar(64),
    PatternName nvarchar(64),
    EliminationGame bit,
    IsContinued bit,
    SessionGamesPlayedId int,
    SessionPlayedId int,
    GamingDate smalldatetime,
    GamingSession tinyint,
    OperatorId int,
    ProgramName nvarchar(64)
)

-- Load all of the game data
insert @gameTable
		(DTStart, DTEnd, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName, PatternName, EliminationGame, IsContinued,
		SessionGamesPlayedID, SessionPlayedID, GamingDate, GamingSession, OperatorID, ProgramName)
select  SGP.DTStart, SGP.DTEnd, SGP.GameSeqNo, SGP.DisplayGameNo, SGP.DisplayPartNo, SGP.GameName, 
		(select top(1) PatternName from SessionGamesPlayedPattern where SessionGamesPlayedID = SGP.SessionGamesPlayedID), --DE10065
		SGP.EliminationGame, SGP.IsContinued, SGP.SessionGamesPlayedID, SP.SessionPlayedID, SP.GamingDate, SP.GamingSession, SP.OperatorID, SP.ProgramName
from (select distinct SessionPlayedID, GamingSession, GamingDate, ProgramName, OperatorID	--Use derived table to
			from History.dbo.SessionPlayed (nolock)		--eliminate UK duplicates
			) as SP 
join History.dbo.SessionGamesPlayed SGP (nolock) on SP.SessionPlayedID = SGP.SessionPlayedID
--join SessionGamesPlayedPattern SGPP(nolock) on SGP.SessionGamesPlayedID = SGPP.SessionGamesPlayedID
where (SP.GamingDate >= cast(convert(varchar(24), @StartDate, 101) as smalldatetime)
and SP.GamingDate  <= cast(convert(varchar(24), @EndDate, 101) as smalldatetime))
and exists (select 1 from History.dbo.GameBallsCalled where SessionGamesPlayedID = SGP.SessionGamesPlayedID) -- Specified to use the History db.
and SP.OperatorID = @OperatorID 
and (@Session = 0 or SP.GamingSession = @Session)
order by DTStart;

declare GameBallCursor cursor for
select DTStart, DTEnd, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName, PatternName, EliminationGame, IsContinued,
    SessionGamesPlayedId, SessionPlayedId, GamingDate, GamingSession,OperatorId, ProgramName
from @gameTable;

declare @DTStart datetime,
    @DTEnd   datetime,
    @GameSeqNo int,
    @DisplayGameNo int,
    @DisplayPartNo nvarchar(64),
    @GameName nvarchar(64),
    @PatternName nvarchar(64),
    @EliminationGame bit,
    @IsContinued bit,
    @SessionGamesPlayedId int,
    @SessionPlayedId int,
    @GamingDate smalldatetime,
    @GamingSession tinyint,
    @TableOperatorId int,
    @ProgramName nvarchar(64),
    @AddBalls bit

--set @AddBalls = 1

OPEN GameBallCursor

fetch next from GameBallCursor into @DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName,
    @PatternName, @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @GamingDate,
    @GamingSession, @TableOperatorId, @ProgramName;
while @@FETCH_STATUS = 0
begin
    insert into #tempRPT
        (DTStart, DTEnd, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName,
         PatternName, EliminationGame, IsContinued, SessionGamesPlayedId, SessionPlayedId, GamingDate,
         GamingSession,OperatorId, ProgramName)
    values
        (@DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName, @PatternName,
   --      (select top(1) PatternName
			--from SessionGamesPlayedPattern
			--where SessionGamesPlayedID = @SessionGamesPlayedId), -- DE10065
         @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @GamingDate,
         @GamingSession, @TableOperatorId, @ProgramName);

    --if @AddBalls = 1 or @EliminationGame = 0
    --begin
        --Load all of the ball call data
        insert #tempRPT
            (CalledTime, BallCalled, BallCalledStatus, SessionGamesPlayedId, SessionPlayedId, GamingDate, GamingSession, OperatorId, ProgramName)
        select
            CalledTime, Ballcalled, CallStatus, @SessionGamesPlayedId, @SessionPlayedId, @GamingDate, @GamingSession, @TableOperatorId, @ProgramName
        from
            history.dbo.GameBallsCalled
        where
            SessionGamesPlayedId = @SessionGamesPlayedId
        order by CalledTime
--    end

--    set @AddBalls = case when @EliminationGame = 1 then 0 else 1 end

    fetch next from GameBallCursor into @DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName,
        @PatternName, @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @GamingDate,
        @GamingSession, @TableOperatorId, @ProgramName;
END

CLOSE GameBallCursor
DEALLOCATE GameBallCursor

--Load all of the card face data
insert #TempRPT (
	CardFace,
	CardNumber,
	CreditPaid,
	CashPaid,
	SessionGamesPlayedID,
	SessionPlayedID,
	GamingDate,
	GamingSession,
	OperatorID,
	ProgramName)
select bcdCardFace,
	bcdCardNo,
	pgwdCreditPaid,
	pgwdCashPaid,
	SGP.SessionGamesPlayedID,
	SP.SessionPlayedID,
	SP.GamingDate,
	SP.GamingSession, 
	SP.OperatorID,
	SP.ProgramName
from (select distinct SessionPlayedID, GamingSession, gamingdate, programname, OperatorID	--Use derived table to
			from History.dbo.SessionPlayed (nolock)		--eliminate UK duplicates
			) as SP 
join History.dbo.SessionGamesPlayed SGP (nolock) ON SP.SessionPlayedID = SGP.SessionPlayedID
join ProgramGameWinners (nolock) ON SGP.SessionGamesPlayedID = pgwSessionGamesPlayedID
join ProgramGameWinnersDetail (nolock) on pgwSessionGamesPlayedID = pgwdSessionGamesPlayedID
	and pgwMasterCardNo = pgwdMasterCardNo
	and pgwPermID = pgwdPermID
join BingoCardDetail (nolock) on pgwSessionGamesPlayedID = bcdSessionGamesPlayedID
	and pgwMasterCardNo = bcdMasterCardNo
where (SP.GamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime)
and SP.GamingDate  <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime))
and SP.OperatorID = @OperatorID
and (@Session = 0 or SP.GamingSession = @Session);

select * from #tempRpt;

drop table #tempRPT;

set nocount off;



GO

