USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryAttendance]    Script Date: 10/07/2013 17:47:48 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummaryAttendance]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummaryAttendance]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryAttendance]    Script Date: 10/07/2013 17:47:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptSessionSummaryAttendance] 
(
    @OperatorID as int,
    @GameDate as datetime,
    @Session as int,
    @IncludeConcession as int,
    @IncludeMerchandise as int,
    @IncludePullTab as int
)    
as
begin
    set nocount on;
    
    -- Validate params
    if(@OperatorID < 0) return 11051621;
    if(@GameDate < '1/1/2000') return 11051622;
    if(@Session < 0) return 11051623;
    if(@IncludeConcession < 0 or @IncludeConcession > 1) return 11051624;
    if(@IncludeMerchandise < 0 or @IncludeMerchandise > 1) return 11051625;
    if(@IncludePullTab < 0 or @IncludePullTab > 1) return 11051626;
    
    declare @Attendance table 
    (
        opId int,
        gameDate datetime,
        sessionNbr int,
        sessionAttend int,
        playerSpend money,
        concessionsSpend money,
        merchandiseSpend money,
        pulltabSpend money,
        bingoSpend money,
        accrualBasedPayout decimal(7,2),
        accrualBasedHold decimal(7,2),
        cashBasedPayout decimal(7,2),
        cashBasedHold decimal(7,2)
    );
    
    DECLARE @SessionPlayedID int

    SELECT @SessionPlayedID  = dbo.GetSessionPlayedForSessionSummary(@GameDate, @Session, @OperatorID)

    -------------------------------------------------------------------------------------------
    -- Return test data...    
    INSERT INTO @Attendance
    (
        opId,
        gameDate,
        sessionNbr,
        sessionAttend,
        playerSpend,
        concessionsSpend,
        merchandiseSpend,
        pulltabSpend,
        bingoSpend,
        accrualBasedPayout,
        accrualBasedHold,
        cashBasedPayout,
        cashBasedHold
    )
    SELECT	@OperatorId, 
			@GameDate, 
			@Session, 
			ss.ManAttendance, 
			dbo.GetSessionSummaryPlayerSpend(ss.SessionSummaryID),
			dbo.GetSessionSummaryConcessionsSpend(ss.SessionSummaryID),
			dbo.GetSessionSummaryMerchandiseSpend(ss.SessionSummaryID),
			dbo.GetSessionSummaryPullTabSpend(ss.SessionSummaryID),
			dbo.GetSessionSummaryBingoSpend(ss.SessionSummaryID),
			dbo.GetSessionSummaryAccrualBasedPayoutPercent(ss.SessionSummaryID),				 
			dbo.GetSessionSummaryAccrualBasedHoldPercent(ss.SessionSummaryID),
			dbo.GetSessionSummaryCashBasedPayoutPercent(ss.SessionSummaryID),				 
			dbo.GetSessionSummaryCashBasedHoldPercent(ss.SessionSummaryID)
    FROM SessionSummary ss
    WHERE ss.SessionPlayedID = @SessionPlayedID
    -------------------------------------------------------------------------------------------

    SELECT * FROM @Attendance;
    
end;



GO

