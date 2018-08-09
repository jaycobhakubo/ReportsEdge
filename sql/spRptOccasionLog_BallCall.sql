USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_BallCall]    Script Date: 12/10/2012 16:31:51 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionLog_BallCall]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionLog_BallCall]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_BallCall]    Script Date: 12/10/2012 16:31:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Batch submitted through debugger: SQLQuery7.sql|7|0|C:\Documents and Settings\Administrator\Local Settings\Temp\~vs315.sql


-- =============================================
-- Author:		<FortuNet>
-- Create date: <11/29/2012>
-- Description:	<End of Occasion Log - List of the ball calls for each game played.>
-- <12/10/2012 tmp - Once the ball call history has been moved to the History.GameBallsCalled
-- table the ball calls were not being returned.>
-- =============================================

CREATE PROCEDURE [dbo].[spRptOccasionLog_BallCall]
(
	@OperatorID as Int,
	@StartDate as DateTime,
	@Session as Int
)
AS
BEGIN
	
SET NOCOUNT ON;

Set ANSI_WARNINGS OFF;

Declare @EndDate as DateTime
Set @EndDate = @StartDate

-- For testing	
--Set @OperatorID = 1
--Set @StartDate = '04/04/2012'
--Set @Session = 1

Declare @Results table  
(
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
	SessionPlayedID int, 
	SessionGamesPlayedID int,
	EliminationGame bit,
    IsContinued bit,
	GamingDate smalldatetime, 
	GamingSession tinyint, 
	OperatorID int, 
	ProgramName nvarchar(64)
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
where SP.GamingDate >= cast(convert(varchar(24), @StartDate, 101) as smalldatetime)
and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and exists (select 1 from History.dbo.GameBallsCalled where SessionGamesPlayedID = SGP.SessionGamesPlayedID) --Specified to use the History.GameBallsCalled table. 
and SP.OperatorID = @OperatorID 
and (@Session = 0 or SP.GamingSession = @Session)
Order by DTStart;

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
    @GamingSession tinyint,
    @TableOperatorId int,
    @ProgramName nvarchar(64),
    @AddBalls bit

--set @AddBalls = 1

OPEN GameBallCursor

fetch next from GameBallCursor into @DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName,
    @PatternName, @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @StartDate,
    @GamingSession, @TableOperatorId, @ProgramName;
while @@FETCH_STATUS = 0
begin
    insert into @Results
        (DTStart, DTEnd, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName,
         PatternName, EliminationGame, IsContinued, SessionGamesPlayedId, SessionPlayedId, GamingDate,
         GamingSession,OperatorId, ProgramName)
    values
        (@DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName, @PatternName,
         @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @StartDate,
         @GamingSession, @TableOperatorId, @ProgramName);

    --if @AddBalls = 1 or @EliminationGame = 0
    --begin
        --Load all of the ball call data
        insert @Results
            (CalledTime, BallCalled, BallCalledStatus, SessionGamesPlayedId, SessionPlayedId, GamingDate, GamingSession, OperatorId, ProgramName)
        select
            CalledTime, Ballcalled, CallStatus, @SessionGamesPlayedId, @SessionPlayedId, @StartDate, @GamingSession, @TableOperatorId, @ProgramName
        from
            history.dbo.GameBallsCalled
        where
            SessionGamesPlayedId = @SessionGamesPlayedId
        order by CalledTime
--    end

--    set @AddBalls = case when @EliminationGame = 1 then 0 else 1 end

    fetch next from GameBallCursor into @DTStart, @DTEnd, @GameSeqNo, @DisplayGameNo, @DisplayPartNo, @GameName,
        @PatternName, @EliminationGame, @IsContinued, @SessionGamesPlayedId, @SessionPlayedId, @StartDate,
        @GamingSession, @TableOperatorId, @ProgramName;
END

CLOSE GameBallCursor
DEALLOCATE GameBallCursor

select * from @Results

Set Nocount off

End
GO

