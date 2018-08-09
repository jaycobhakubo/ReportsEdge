USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryAttendance]    Script Date: 01/06/2012 08:33:16 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummaryAttendance]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummaryAttendance]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryAttendance]    Script Date: 01/06/2012 08:33:16 ******/
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
        bingoPayout decimal(7,2),
        bingoHold decimal(7,2)
    );
    
    DECLARE @SessionPlayedID int

    SELECT @SessionPlayedID  = dbo.GetSessionPlayedForSessionSummary(@GameDate, @Session, @OperatorID)

    -------------------------------------------------------------------------------------------
    -- Return test data...    
    INSERT INTO @Attendance (opId, gameDate, sessionNbr, sessionAttend, playerSpend, concessionsSpend, merchandiseSpend, pulltabSpend, bingoSpend, bingoPayout, bingoHold)
    SELECT	@OperatorId, 
			@GameDate, 
			@Session, 
			ss.ManAttendance, 
			CASE WHEN ss.ManAttendance = 0 THEN 0
				 ELSE (ss.PaperSales + ss.ElectronicSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales - ss.Discounts) / ss.ManAttendance
				 END,
			CASE WHEN ss.ManAttendance = 0 THEN 0
				 ELSE ss.ConcessionSales / ss.ManAttendance
				 END,
			CASE WHEN ss.ManAttendance = 0 THEN 0
				 ELSE ss.MerchandiseSales / ss.ManAttendance
				 END,
			CASE WHEN ss.ManAttendance = 0 THEN 0
				 ELSE ss.PullTabSales / ss.ManAttendance
				 END,
			CASE WHEN ss.ManAttendance = 0 THEN 0
				 ELSE (ss.PaperSales + ss.ElectronicSales) / ss.ManAttendance
				 END,
			CASE WHEN (ss.PaperSales + ss.ElectronicSales + ss.BingoOtherSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales - ss.Discounts) = 0 THEN 0
				 ELSE ((ss.CashPrizes + ss.CheckPrizes + ss.MerchandisePrizes + ss.AccrualIncrease + ss.PullTabPrizes) * 100) / (ss.PaperSales + ss.ElectronicSales + ss.BingoOtherSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales - ss.Discounts)
				 END,				 
			CASE WHEN (ss.PaperSales + ss.ElectronicSales + ss.BingoOtherSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales - ss.Discounts) = 0 THEN 0
				 ELSE 100 - ((ss.CashPrizes + ss.CheckPrizes + ss.MerchandisePrizes + ss.AccrualIncrease + ss.PullTabPrizes) * 100) / (ss.PaperSales + ss.ElectronicSales + ss.BingoOtherSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales - ss.Discounts)
				 END		
    FROM SessionSummary ss
    WHERE ss.SessionPlayedID = @SessionPlayedID
    -------------------------------------------------------------------------------------------

    SELECT * FROM @Attendance;
    
end;

GO


