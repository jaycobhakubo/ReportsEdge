USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummarySales]    Script Date: 10/15/2013 11:50:18 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummarySales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummarySales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummarySales]    Script Date: 10/15/2013 11:50:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptSessionSummarySales] 
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
    if(@OperatorID < 0) return 11051651;
    if(@GameDate < '1/1/2000') return 11051652;
    if(@Session < 0) return 11051653;
    if(@IncludeConcession < 0 or @IncludeConcession > 1) return 11051654;
    if(@IncludeMerchandise < 0 or @IncludeMerchandise > 1) return 11051655;
    if(@IncludePullTab < 0 or @IncludePullTab > 1) return 11051656;
    
    declare @Sales table 
    (
        opId int,
        gameDate datetime,
        sessionNbr int,
        paper money,
        electronic money,
        bingoOther money,
        pulltab money,
        concessions money,
        merchandise money,
        cashPrizes money,
        checkPrizes money,
        merchPrizes money,
        accrualIncreases money,
        pullTabPrizes money,
        otherPrizes money,
        beginBank money,
        accrualPayouts money,
        prizeFees money,
        sessionCosts money,
        coupons money,
        actualCash money,
        debitCredit money,
        checks money,
        endBank money,
        deposits money,
        discounts money,
        tax money,
        sessionCostNonRegister money,
        comments nvarchar(255),
        moneyOrders money,
        giftCards money,
        chips money,
        deviceFees money,
        accrualCashPayouts money
        
    );
    
    DECLARE @SessionPlayedID int
    DECLARE @SessionSummaryID int
    DECLARE @SessionCostsRegister money
    DECLARE @SessionCostsNonregister money
    -- Get the session played id
    SELECT @SessionPlayedID  = dbo.GetSessionPlayedForSessionSummary(@GameDate, @Session, @OperatorID)
    -- Get the session summary id
    SELECT @SessionSummaryID = ss.SessionSummaryID FROM SessionSummary ss WHERE ss.SessionPlayedID = @SessionPlayedID
    
    -- Get session costs from register
    SELECT @SessionCostsRegister = ISNULL(SUM(sci.Value), 0)
	FROM SessionSummarySessionCosts sc JOIN SessionCostItem sci ON sc.SessionCostItemID = sci.Id
	WHERE sc.SessionSummaryID = @SessionSummaryID AND sci.IsRegister = 1
	
	-- Get session costs from nonregister	
	SELECT @SessionCostsNonregister = ISNULL(SUM(sci.Value), 0)
	FROM SessionSummarySessionCosts sc JOIN SessionCostItem sci ON sc.SessionCostItemID = sci.Id
	WHERE sc.SessionSummaryID = @SessionSummaryID AND sci.IsRegister = 0
    
    INSERT INTO @Sales ( opId, gameDate, sessionNbr, paper, electronic, bingoOther, pulltab, concessions, merchandise
                        ,cashPrizes, checkPrizes, merchPrizes, accrualIncreases, pullTabPrizes, otherPrizes
                        ,beginBank, accrualPayouts, prizeFees, sessionCosts, coupons, actualCash, debitCredit, checks, endBank
                        ,deposits
                        ,discounts, tax, sessionCostNonRegister, comments, moneyOrders, giftCards, chips
                        ,deviceFees,accrualCashPayouts )                        
	SELECT @OperatorID, @GameDate, @Session, ss.PaperSales, ss.ElectronicSales, ss.BingoOtherSales, ss.PullTabSales, ss.ConcessionSales, ss.MerchandiseSales
		   ,ss.CashPrizes, ss.CheckPrizes, ss.MerchandisePrizes, ss.AccrualIncrease, ss.PullTabPrizes, ss.OtherPrizes
		   ,ss.BeginningBank, ss.AccrualPayouts, ss.PrizeFeesWithheld, @SessionCostsRegister, ss.Coupons, ss.ActualCash, ss.DebitCredit, ss.Checks, ss.EndingBank
		   ,(ss.ActualCash + ss.DebitCredit + ss.Checks + ss.MoneyOrders + ss.Chips - ss.EndingBank)
		   , ss.Discounts, ss.Tax, @SessionCostsNonRegister, ss.Comments, ss.MoneyOrders, ss.GiftCards, ss.Chips
		   , ss.DeviceFees, ss.AccrualCashPayouts
	FROM SessionSummary ss
	WHERE ss.SessionPlayedID = @SessionPlayedID

    select * from @Sales;
    
end;





GO

