USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryPctSales]    Script Date: 08/15/2011 16:03:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummaryPctSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummaryPctSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryPctSales]    Script Date: 08/15/2011 16:03:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptSessionSummaryPctSales] 
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
    if(@OperatorID < 0) return 11051641;
    if(@GameDate < '1/1/2000') return 11051642;
    if(@Session < 0) return 11051643;
    if(@IncludeConcession < 0 or @IncludeConcession > 1) return 11051644;
    if(@IncludeMerchandise < 0 or @IncludeMerchandise > 1) return 11051645;
    if(@IncludePullTab < 0 or @IncludePullTab > 1) return 11051646;
    
    declare @PctSales table 
    (
        opId int,
        gameDate datetime,
        sessionNbr int,
        paper decimal(7,2),
        electronics decimal(7,2),
        bingoOther decimal(7,2),
        pullTabs decimal(7,2),
        concessions decimal(7,2),
        merchandise decimal(7,2)
    );
    
    DECLARE @SessionPlayedID int
    DECLARE @TotalSales decimal(7,2)
    -- Get the session summary session played id
    SELECT @SessionPlayedID  = dbo.GetSessionPlayedForSessionSummary(@GameDate, @Session, @OperatorID)
    
    -- Get the total sales figure
    SELECT @TotalSales = (ss.PaperSales + ss.ElectronicSales + ss.BingoOtherSales + ss.PullTabSales + ss.ConcessionSales + ss.MerchandiseSales)
    FROM SessionSummary ss
    WHERE ss.SessionPlayedID = @SessionPlayedID
    
    -- validate total sales
    IF (@TotalSales > 0)
		BEGIN
		INSERT INTO @PctSales (opId, gameDate, sessionNbr, paper, electronics, bingoOther, pullTabs, concessions, merchandise)
		SELECT @OperatorId,
			   @GameDate,
			   @Session,
			   (ss.PaperSales * 100)/ @TotalSales,
			   (ss.ElectronicSales * 100) / @TotalSales,
			   (ss.BingoOtherSales * 100) / @TotalSales,
			   (ss.PullTabSales * 100) / @TotalSales,
			   (ss.ConcessionSales * 100) / @TotalSales,
			   (ss.MerchandiseSales * 100) / @TotalSales
		FROM SessionSummary ss
		WHERE ss.SessionPlayedID = @SessionPlayedID
		END
	ELSE
		BEGIN
		-- Total sales was 0 or less so set percentage sales to 0
		INSERT INTO @PctSales (opId, gameDate, sessionNbr, paper, electronics, bingoOther, pullTabs, concessions, merchandise)
		VALUES (@OperatorId, @GameDate, @Session, 0, 0, 0, 0, 0, 0)
		END

    select * from @PctSales;
    
end;

GO


