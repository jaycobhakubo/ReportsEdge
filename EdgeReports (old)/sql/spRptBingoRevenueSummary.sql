USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoRevenueSummary]    Script Date: 01/06/2012 08:41:59 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBingoRevenueSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBingoRevenueSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoRevenueSummary]    Script Date: 01/06/2012 08:41:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Barry J. Silver
-- Description:	CASH BASED
--              Provide periodic summary of sales and payout info
--              This report is offered in 2 styles: Cash Based and Accrual Based.
--              Cash Based gross revenue=sales-prizes-payouts
--              Accrual based gross rev=sales-prizes-accrual increases
-- Note: sp named differently than its twin (spRptBingoRevenueSummaryAccrual) to retain biz logic in Crystal.
--
-- BJS 05/31/2011: US1851 new report
-- BJS 06/17/2011: DE8676 session number
-- bjs 06/21/2011: missing bingo sales
-- LJL 06/23/2011: Removed voided payouts from result set
-- BDH 02/22/2012: Fixed discount calculation
-- 2012.04.05 jkn: Adding support for returning data based on a fiscal date
--		not only the date range
-- =============================================
ALTER PROCEDURE  [dbo].[spRptBingoRevenueSummary] 
(
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session    int
)
AS
BEGIN
    SET NOCOUNT ON;
    
    --
    -- Set optional values to null
    --
    SET @OperatorID = NULLIF(@OperatorID, 0);
    SET @Session = NULL;--NULLIF(@Session, 0);
    
    declare @ReportStart datetime
		, @ReportEnd datetime
		, @FiscalYearStart datetime
		
	select @FiscalYearStart = SettingValue
	from GlobalSettings
	where GlobalSettingId = 164 --Start of Fiscal Year setting
	
	set @StartDate = cast (cast (datepart(month, @FiscalYearStart) as nvarchar) + '/' +
						   cast (datepart(day, @FiscalYearStart) as nvarchar)  + '/' +
						   cast ((datepart(year, @EndDate) - 1) as nvarchar) as datetime)
	
	set @FiscalYearStart = dateadd(year, 1, @StartDate)
	
    --
    -- Declare our temporary results table for this report
    --
    DECLARE @Results TABLE
    (
		 Yr					INT
		,FiscalYearStart	SMALLDATETIME
		,MonthInt			INT
		,MonthNm			NVARCHAR(32)	
		,SessionPlayedID	INT
		,GamingDate			SMALLDATETIME	
		,SessionNumber		TINYINT
		,Attendance			INT
		,BingoSales			MONEY
		,BingoPrizes		MONEY
		,AccrualPayouts		MONEY
		,AccrualIncreases	MONEY
    );
    
    --
    -- Create a result row for each session in the system
    -- for the date range passed
    --
    INSERT INTO @Results
    (
		 GamingDate
		,SessionNumber
		,SessionPlayedID
		,BingoSales
		,Attendance
    )
    SELECT
		 sp.GamingDate
		,sp.GamingSession
		,sp.SessionPlayedID
		,0
		,0
    FROM SessionPlayed sp
    WHERE	(sp.OperatorID = @OperatorID OR @OperatorID IS NULL) AND
			(sp.GamingDate >= @StartDate) AND
			(sp.GamingDate <= @EndDate) AND
			(sp.GamingSession = @Session OR @Session IS NULL) AND
			(sp.IsOverridden = 0);
			
	--
	-- Update results with attendance values from session summary
	--			
	UPDATE @Results
	SET Attendance = ss.ManAttendance
	FROM @Results r
		JOIN SessionSummary ss ON (r.SessionPlayedID = ss.SessionPlayedID);
		
	--
	-- Calculate our payouts for each session in our list
	--		
	DECLARE @TempPayouts TABLE
	(
		 PayoutTransID		INT
		,GamingDate			SMALLDATETIME
		,SessionNumber		TINYINT
		,BingoPayout		MONEY
		,AccrualPayout		MONEY
	);
	
	--
	-- Insert all payouts for the date range and operator into
	-- payout temp table
	--
	INSERT INTO @TempPayouts
	SELECT	 p.PayoutTransID
			,p.GamingDate
			,NULL
			,0
			,0
	FROM PayoutTrans p
	WHERE	(@OperatorID IS NULL OR @OperatorID = p.OperatorID) AND
			(p.GamingDate >= @StartDate) AND
			(p.GamingDate <= @EndDate) AND
			 p.TransTypeID = 36 AND -- Only Payouts    
			 p.VoidTransID IS NULL -- Not Voided	
			 
	--
	-- Update records for Bingo Custom Session Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Session Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)		
	
	--
	-- Update records for Bingo Custom Game Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Good Neighbor Game Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoGoodNeighbor ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		
		
	--
	-- Update records for Bingo Royalty Game Payouts
	--
	UPDATE @TempPayouts
	SET	 SessionNumber = sp.GamingSession
	FROM @TempPayouts r
		JOIN PayoutTransBingoRoyalty ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		        
    
	--
	-- Add in "Cash" information to payouts
	--
	UPDATE @TempPayouts
	SET	 BingoPayout = BingoPayout + (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCash WHERE PayoutTransID = r.PayoutTransID)
	FROM @TempPayouts r
		JOIN PayoutTransDetailCash ptd ON (ptd.PayoutTransID = r.PayoutTransID)	
		
	--
	-- Add in "Check" information to payouts
	--
	UPDATE @TempPayouts
	SET	 BingoPayout = BingoPayout + (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCheck WHERE PayoutTransID = r.PayoutTransID)
	FROM @TempPayouts r
		JOIN PayoutTransDetailCheck ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Credit" information to payouts
	--
	UPDATE @TempPayouts
	SET	 BingoPayout = BingoPayout + (SELECT SUM(ISNULL(Refundable, 0)) + SUM(ISNULL(NonRefundable, 0)) FROM PayoutTransDetailCredit WHERE PayoutTransID = r.PayoutTransID)
	FROM @TempPayouts r
		JOIN PayoutTransDetailCredit ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Merchandise" information to payouts
	--
	UPDATE @TempPayouts
	SET	 BingoPayout = BingoPayout + (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailMerchandise WHERE PayoutTransID = r.PayoutTransID)
	FROM @TempPayouts r
		JOIN PayoutTransDetailMerchandise ptd ON (ptd.PayoutTransID = r.PayoutTransID)				

	--
	-- Add in "Other" information to payouts
	--
	UPDATE @TempPayouts
	SET	 BingoPayout = BingoPayout + (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailOther WHERE PayoutTransID = r.PayoutTransID)
	FROM @TempPayouts r
		JOIN PayoutTransDetailOther ptd ON (ptd.PayoutTransID = r.PayoutTransID)			 
	
	--
	-- Add in the Accrual Payouts
	--    
	INSERT INTO @TempPayouts
	(
		 GamingDate
		,SessionNumber
		,AccrualPayout
	)
	SELECT	 sp.GamingDate
			,sp.GamingSession
			,SUM(-1 * atd.Value)
	FROM AccrualTransactions at
		JOIN AccrualTransactionDetails atd ON (at.AccrualTransactionID = atd.AccrualTransactionID)
		JOIN SessionPlayed sp ON (at.SessionPlayedID = sp.SessionPlayedID)
	WHERE	(sp.OperatorID = @OperatorID OR @OperatorID IS NULL) AND
			(sp.GamingSession = @Session OR @Session IS NULL) AND
			(sp.GamingDate >= @StartDate) AND
			(sp.GamingDate <= @EndDate) AND
			(sp.IsOverridden = 0) AND
			(at.TransactionTypeID = 36)
	GROUP BY sp.GamingDate, sp.GamingSession
	
	--
	-- Add our newly calculated data into our results set
	--
	UPDATE @Results
	SET AccrualPayouts = (SELECT ISNULL(SUM(ISNULL(AccrualPayout, 0)), 0) FROM @TempPayouts WHERE GamingDate = r.GamingDate AND SessionNumber = r.SessionNumber)
	FROM @Results r;
	
	UPDATE @Results
	SET BingoPrizes = (SELECT ISNULL(SUM(ISNULL(BingoPayout, 0)), 0) FROM @TempPayouts WHERE GamingDate = r.GamingDate AND SessionNumber = r.SessionNumber)
	FROM @Results r;
	
	--
	-- Do not double count accrual payouts
	--
	UPDATE @Results
	SET BingoPrizes = BingoPrizes - AccrualPayouts
	WHERE BingoPrizes >= AccrualPayouts
	
	--
	-- Add in the accrual increases for each session
	--
	DECLARE @TempAccrualIncreases TABLE
	(
		 GamingDate		SMALLDATETIME
		,SessionNumber	TINYINT
		,AccrualPayout	MONEY
	)
	INSERT INTO @TempAccrualIncreases
	(
		 GamingDate
		,SessionNumber
		,AccrualPayout
	)
	SELECT	 sp.GamingDate
			,sp.GamingSession
			,SUM(atd.Value)
	FROM AccrualTransactions at
	JOIN AccrualTransactionDetails atd ON (at.AccrualTransactionID = atd.AccrualTransactionID)
	JOIN SessionPlayed sp ON (at.SessionPlayedID = sp.SessionPlayedID)
	WHERE	(sp.OperatorID = @OperatorID OR @OperatorID IS NULL) AND
			(sp.GamingSession = @Session OR @Session IS NULL) AND
			(sp.GamingDate >= @StartDate) AND
			(sp.GamingDate <= @EndDate) AND
			(sp.IsOverridden = 0) AND
			(at.TransactionTypeID IN (5, 37))
	GROUP BY sp.GamingDate, sp.GamingSession
	
	UPDATE @Results
	SET AccrualIncreases = ISNULL((SELECT AccrualPayout 
									   FROM @TempAccrualIncreases 
									   WHERE	GamingDate = r.GamingDate
									   		AND SessionNumber = r.SessionNumber), 0)
	FROM @Results r
	
	
	--
	-- Calculate sales
	--
	DECLARE @TmpPaperSales TABLE
	(
		 GamingDate		SMALLDATETIME
		,SessionNo		TINYINT
		,RegisterPaper	MONEY
		,FloorPaper		MONEY
	);		
	INSERT INTO @TmpPaperSales
	SELECT	 GamingDate
			,SessionNo
			,SUM(RegisterPaper)
			,SUM(FloorPaper)
	FROM FindPaperSales(ISNULL(@OperatorID, 0), @StartDate, @EndDate, ISNULL(@Session, 0))
	GROUP BY GamingDate, SessionNo
	
	UPDATE @Results
	SET BingoSales = ISNULL((SELECT ISNULL(RegisterPaper, 0) + ISNULL(FloorPaper, 0)
					  FROM @TmpPaperSales
					  WHERE GamingDate = r.GamingDate
					  AND SessionNo = r.SessionNumber), 0)
	FROM @Results r
    
    --
    -- Handle Non-Paper Bingo Sales (Taken from [spRptSalesByPackageTotals])    
    --
	declare @Sales table
	(
		gamingDate datetime,
		sessionNumber int,
		totalSales money
	);
	--		
	-- Insert Electronic Rows		
	--
	insert into @Sales
	(
		gamingDate,
		sessionNumber,
		totalSales
	)
	select rr.GamingDate,
		sp.GamingSession,
		sum((rd.Quantity * rdi.Qty * (case when rr.TransactionTypeID = 1 then rdi.Price else -rdi.Price end)))
	from RegisterReceipt rr
		join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
		join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
		left join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
	where rr.GamingDate >= @StartDate
		and rr.GamingDate <= @EndDate
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.TransactionTypeID in (1, 3) -- sale or return
		and (@OperatorID is null or rr.OperatorID = @OperatorID)
		and ((rdi.ProductTypeID in (1, 2, 3, 4) and rdi.CardMediaID = 1) 
			or rdi.ProductTypeID in (5, 6, 7, 14, 17))
		and (@Session is null or sp.GamingSession = @Session)
	group by rr.GamingDate, sp.GamingSession;
	
	-- Account for discounts
	insert into @Sales
	(
		gamingDate,
		sessionNumber,
		totalSales
	)
	select rr.GamingDate,
		sp.GamingSession,
		sum((case when rr.TransactionTypeID = 1 then rd.DiscountAmount else -rd.DiscountAmount end) * rd.Quantity)
	from RegisterReceipt rr
		join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
		left join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
	where rr.GamingDate >= @StartDate
		and rr.GamingDate <= @EndDate
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.TransactionTypeID in (1, 3) -- sale or return
		and (@OperatorID is null or rr.OperatorID = @OperatorID)
		and (@Session is null or sp.GamingSession = @Session)
	group by rr.GamingDate, sp.GamingSession;   
	    
	UPDATE @Results
	SET BingoSales = BingoSales + ISNULL((SELECT SUM(ISNULL(totalSales, 0))
								          FROM @Sales s
								          WHERE s.gamingDate = r.GamingDate
								          AND s.sessionNumber = r.SessionNumber), 0)
	FROM @Results r	    
    
    --
    -- Update Year / Date parts
	--
	UPDATE @Results
--	SET  Yr = DATEPART(year, r.GamingDate)
	SET  Yr = case when r.GamingDate < @FiscalYearStart then (datepart(year, r.GamingDate) - 1) else DATEPART(year, r.GamingDate)end
--		,Qtr = 'Q' + CONVERT(NVARCHAR(3), datepart(quarter, r.GamingDate))
		,FiscalYearStart = @FiscalYearStart
		,MonthInt = MONTH(r.GamingDate)
		,MonthNm = DATENAME(MONTH, r.GamingDate)
	FROM @Results r

    
    --
    -- Select our result set to the client
    --    
    SELECT 
		 Yr
		,FiscalYearStart
		,MonthInt
		,MonthNm
		,GamingDate
		,SessionNumber
		,Attendance
		,BingoSales
		,BingoPrizes
		,AccrualPayouts
		,AccrualIncreases
	FROM @Results;
    
    SET NOCOUNT OFF;
END;
go