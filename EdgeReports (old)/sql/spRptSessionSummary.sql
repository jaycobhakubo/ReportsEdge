USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummary]    Script Date: 07/30/2012 12:33:49 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummary]    Script Date: 07/30/2012 12:33:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptSessionSummary] 
(
    @OperatorID INT,
    @Session INT,
    @IncludeConcessions INT,
    @GamingDate DATETIME,
    @IncludeMerchandise INT,
    @IncludePullTabs INT
)    
AS
--=============================================================================
-- DE8884 - Include discounts; both hacked and regular
-- DE10632 jkn: Modified the device fees calculation to include only the 
--  requested session fees
--=============================================================================

BEGIN

SET NOCOUNT ON

    -- Validate params
    --if(@OperatorID < 0) return 1105161;
    --if(@GameDate < '1/1/2000') return 1105162;
    --if(@Session < 0) return 1105163;
    --if(@IncludeConcession < 0 or @IncludeConcession > 1) return 1105164;
    --if(@IncludeMerchandise < 0 or @IncludeMerchandise > 1) return 1105165;
    --if(@IncludePullTab < 0 or @IncludePullTab > 1) return 1105166;

--
-- Create the table to hold our result sets
--
DECLARE @Results TABLE
(
	ProductName			NVARCHAR(64),
	PaperSales			MONEY,
	ElectronicSales		MONEY,
	BingoOtherSales		MONEY,
	MerchandiseSales    MONEY,
	ConcessionSales     MONEY,
	PullTabSales        MONEY,	
	Discounts           MONEY,
	CashPrizes			MONEY,
	MerchPrizes			MONEY,
	AccrualIncrease		MONEY,
	Tax					MONEY,
	DeviceFee			MONEY
)


-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR PAPER SALES
-------------------------------------------------------------

--
-- Insert rows for our Paper Sales (Sales - Returns)
--

INSERT INTO @Results
(
	ProductName,
	PaperSales
)
SELECT fps.ItemName, SUM(fps.RegisterPaper + fps.FloorPaper)
FROM dbo.FindPaperSales(@OperatorID, @GamingDate, @GamingDate, @Session) fps
GROUP BY fps.ItemName

--DE10615 Device Fees and Taxes calculations
-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR TAXES
-------------------------------------------------------------

INSERT INTO @Results
(
	ProductName,
	Tax
)
SELECT	N'',
		SUM(rd.SalesTaxAmt) 
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID IN(1,3) AND
		rr.OperatorID = @OperatorID AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL;

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR DEVICE FEES
-- DE10632
-------------------------------------------------------------
with cte_Receipts (ReceiptId)
as
(
    select distinct (rd.RegisterReceiptId)
    from RegisterDetail rd
        join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId
    where rd.VoidedRegisterReceiptId is null
        and sp.GamingDate = @GamingDate
        and (sp.GamingSession = @Session or @Session = 0)
        and sp.OperatorId = @OperatorId
)
INSERT INTO @Results
(
    ProductName,
    DeviceFee
)
SELECT N'',	
	SUM(ISNULL(rr.DeviceFee,0))
FROM RegisterReceipt rr
    join cte_Receipts on rr.RegisterReceiptId = ReceiptId
Where rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND isnull(rr.DeviceFee,0)<>0;

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR ELECTRONIC SALES
-------------------------------------------------------------

--
-- Insert rows for our Electronic Sales (Sales - Returns)
--
INSERT INTO @Results
(
	ProductName,
	ElectronicSales
)
SELECT	rdi.ProductItemName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID IN (1, 2, 3, 4, 5) AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	ElectronicSales
	
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID IN (1, 2, 3, 4, 5) AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Bingo Other SALES
-------------------------------------------------------------
INSERT INTO @Results
(
	ProductName,
	BingoOtherSales
)
SELECT	rdi.ProductItemName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 14 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		NOT rdi.ProductItemName LIKE 'Discount%'
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	BingoOtherSales
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 14 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		NOT rdi.ProductItemName LIKE 'Discount%'
GROUP BY rdi.ProductItemName
-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Merchandise
-------------------------------------------------------------

--
-- Insert rows for our Merchandise Sales (Sales - Returns)
--
INSERT INTO @Results
(
	ProductName,
	MerchandiseSales
)
SELECT	rdi.ProductItemName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 7 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	MerchandiseSales
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 7 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Concessions
-------------------------------------------------------------

--
-- Insert rows for our Concession Sales (Sales - Returns)
--
INSERT INTO @Results
(
	ProductName,
	ConcessionSales
)
SELECT	rdi.ProductItemName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 6 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	ConcessionSales
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 6 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR PullTabSales
-------------------------------------------------------------

--
-- Insert rows for our PullTabSales Sales (Sales - Returns)
--
INSERT INTO @Results
(
	ProductName,
	PullTabSales
)
SELECT	rdi.ProductItemName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 17 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	PullTabSales
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 17 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL 
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Discounts
-------------------------------------------------------------


-- Include discounts into discounts

INSERT INTO @Results
(
	ProductName,
	Discounts
)
SELECT	dt.DiscountTypeName,
		SUM(  rd.DiscountAmount * rd.Quantity)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join DiscountTypes dt on (dt.DiscountTypeID = rd.DiscountTypeID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL
GROUP BY dt.DiscountTypeName

INSERT INTO @Results
(
	ProductName,
	Discounts	
)
SELECT	dt.DiscountTypeName,
		SUM(-1 * rd.DiscountAmount * rd.Quantity)
	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join DiscountTypes dt on (dt.DiscountTypeID = rd.DiscountTypeID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND		
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL
GROUP BY dt.DiscountTypeName

--Hacked discounts
INSERT INTO @Results
(
	ProductName,
	Discounts
)
SELECT	rdi.ProductItemName,
		SUM( rd.Quantity * rdi.Qty * rdi.Price)
	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 14 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		rdi.ProductItemName LIKE 'Discount%'
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductName,
	Discounts
)
SELECT	rdi.ProductItemName,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 14 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		rdi.ProductItemName LIKE 'Discount%'
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR CASH PRIZES AND MERCHANDISE PRIZES
-------------------------------------------------------------
DECLARE @PayoutIDPerSGPID TABLE
(
	PayoutTransID			INT,
	SessionGamesPlayedID	INT,
	GameCategoryID			INT,
	CashPayoutAmount		MONEY,
	MerchPayoutAmount		MONEY
)

--
-- The next few sections match up a payout id to the corresponding sessiongamesplayedid
--

INSERT INTO @PayoutIDPerSGPID
SELECT   
	  pt.PayoutTransID
	 ,sgp.SessionGamesPlayedID
	 ,0
	 ,'0.00'
	 ,'0.00'
FROM 
	PayoutTrans pt
	JOIN PayoutTransBingoCustom ptbc ON (pt.PayoutTransID = ptbc.PayoutTransID)
	JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE	
	@GamingDate = sp.GamingDate AND
	@Session = sp.GamingSession AND
	@OperatorID = sp.OperatorID AND
	pt.TransTypeID = 36 AND
	pt.VoidTransID IS NULL
	
INSERT INTO @PayoutIDPerSGPID
SELECT   
	  pt.PayoutTransID
	 ,sgp.SessionGamesPlayedID
	 ,0
	 ,'0.00'
	 ,'0.00'
FROM 
	PayoutTrans pt
	JOIN PayoutTransBingoGame ptbg ON (pt.PayoutTransID = ptbg.PayoutTransID)
	JOIN SessionGamesPlayed sgp ON (ptbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE	
	@GamingDate = sp.GamingDate AND
	@Session = sp.GamingSession	AND
	@OperatorID = sp.OperatorID AND
	pt.TransTypeID = 36 AND
	pt.VoidTransID IS NULL
	
INSERT INTO @PayoutIDPerSGPID
SELECT   
	  pt.PayoutTransID
	 ,sgp.SessionGamesPlayedID
	 ,0
	 ,'0.00'
	 ,'0.00'
FROM 
	PayoutTrans pt
	JOIN PayoutTransBingoGoodNeighbor ptbg ON (pt.PayoutTransID = ptbg.PayoutTransID)
	JOIN SessionGamesPlayed sgp ON (ptbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE	
	@GamingDate = sp.GamingDate AND
	@Session = sp.GamingSession	AND
	@OperatorID = sp.OperatorID AND
	pt.TransTypeID = 36 AND
	pt.VoidTransID IS NULL
	
INSERT INTO @PayoutIDPerSGPID
SELECT   
	  pt.PayoutTransID
	 ,sgp.SessionGamesPlayedID
	 ,0
	 ,'0.00'
	 ,'0.00'
FROM 
	PayoutTrans pt
	JOIN PayoutTransBingoRoyalty ptbr ON (pt.PayoutTransID = ptbr.PayoutTransID)
	JOIN SessionGamesPlayed sgp ON (ptbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE	
	@GamingDate = sp.GamingDate AND
	@Session = sp.GamingSession	AND
	@OperatorID = sp.OperatorID	AND
	pt.TransTypeID = 36 AND
	pt.VoidTransID IS NULL AND
	pt.AccrualTransID IS NULL -- DE9994 Exclude accrual payouts
	
--
-- For each payoutTrans, add up the Cash and Merc payout amount
--	
UPDATE @PayoutIDPerSGPID
SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.DefaultAmount, '0.00')), '0.00')
											FROM PayoutTransDetailCash ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

UPDATE @PayoutIDPerSGPID
SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.DefaultAmount, '0.00')), '0.00')
											FROM PayoutTransDetailCheck ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

UPDATE @PayoutIDPerSGPID
SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.Refundable, '0.00')), '0.00')
											FROM PayoutTransDetailCredit ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

UPDATE @PayoutIDPerSGPID
SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.NonRefundable, '0.00')), '0.00')
											FROM PayoutTransDetailCredit ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

UPDATE @PayoutIDPerSGPID
SET MerchPayoutAmount = MerchPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.PayoutValue, '0.00')), '0.00')
											FROM PayoutTransDetailMerchandise ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

UPDATE @PayoutIDPerSGPID
SET MerchPayoutAmount = MerchPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.PayoutValue, '0.00')), '0.00')
											FROM PayoutTransDetailOther ptdc
											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
FROM @PayoutIDPerSGPID pips

--
-- Update the game category for each game
--
UPDATE @PayoutIDPerSGPID
SET GameCategoryID =   (SELECT sgp.GameCategoryID
						FROM SessionGamesPlayed sgp
						WHERE SessionGamesPlayedID = pips.SessionGamesPlayedID)
FROM @PayoutIDPerSGPID pips						

--
-- Get the payouts per game category
--
DECLARE @PayoutAmountPerCategory TABLE
(
	GameCategoryID	INT
	,CashAmount		MONEY
	,MercAmount		MONEY
)

INSERT INTO @PayoutAmountPerCategory
SELECT 
	GameCategoryID
	,SUM(CashPayoutAmount)
	,SUM(MerchPayoutAmount)
FROM @PayoutIDPerSGPID
GROUP BY GameCategoryID

--
-- Get the products tied to each game category
--
DECLARE @ProdsPerCategory TABLE
(
	ProductItemName		NVARCHAR(64),
	GameCategoryID		INT
)

INSERT INTO @ProdsPerCategory 
SELECT
	rdi.ProductItemName,
	rdi.GameCategoryID
FROM 
	RegisterDetailItems rdi
	JOIN RegisterDetail rd ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
WHERE 
	GameCategoryID IS NOT NULL AND
	@GamingDate = sp.GamingDate AND
	@Session = sp.GamingSession	AND
	@OperatorID = sp.OperatorID
	
DECLARE @DistinctProdsPerCategory TABLE
(
	ProductItemName		NVARCHAR(64),
	GameCategoryID		INT
)	

INSERT INTO @DistinctProdsPerCategory
SELECT DISTINCT ProductItemName, GameCategoryID
FROM @ProdsPerCategory

--
-- Loop through each product/category combination
-- and give some of the payout to each product
--
DECLARE @CursorProductItemName NVARCHAR(64),
		@CursorGameCategoryID  INT,
		@NumProductsWithCat		INT

DECLARE SessionSummaryCursor CURSOR LOCAL FOR
		SELECT ProductItemName, GameCategoryID
		FROM @DistinctProdsPerCategory
			
OPEN SessionSummaryCursor
FETCH NEXT FROM SessionSummaryCursor INTO @CursorProductItemName, @CursorGameCategoryID

WHILE @@FETCH_STATUS = 0
BEGIN
	--
	-- Get the number of distinct products that were used with this cat
	--
	SET @NumProductsWithCat = (SELECT COUNT(*)
							   FROM @DistinctProdsPerCategory
							   WHERE GameCategoryID = @CursorGameCategoryID)
							   
							   
	UPDATE @Results
	SET CashPrizes = ISNULL(CashPrizes, '0.00') + ISNULL((SELECT CashAmount
								                          FROM @PayoutAmountPerCategory
								                          WHERE GameCategoryID = @CursorGameCategoryID), '0.00') / @NumProductsWithCat,
	MerchPrizes = ISNULL(MerchPrizes, '0.00') + ISNULL((SELECT MercAmount
															FROM @PayoutAmountPerCategory
								                            WHERE GameCategoryID = @CursorGameCategoryID), '0.00') / @NumProductsWithCat
	WHERE ProductName = @CursorProductItemName							   
								   	
	
	FETCH NEXT FROM SessionSummaryCursor INTO @CursorProductItemName, @CursorGameCategoryID
END
CLOSE SessionSummaryCursor
DEALLOCATE SessionSummaryCursor	

--
-- Select out our result outputs
--
SELECT 	ProductName,
		SUM(ISNULL(PaperSales, '0.00'))			AS PaperSales,
		SUM(ISNULL(ElectronicSales, '0.00'))	AS ElectronicSales,
		SUM(ISNULL(BingoOtherSales, '0.00'))	AS BingoOtherSales,
		SUM(ISNULL(ConcessionSales, '0.00'))    AS ConcessionSales,
		SUM(ISNULL(MerchandiseSales, '0.00'))   AS MerchandiseSales,
		SUM(ISNULL(PullTabSales, '0.00'))       AS PullTabSales,
		SUM(ISNULL(Discounts, '0.00'))          AS Discounts,
		MAX(ISNULL(CashPrizes, '0.00'))			AS CashPrizes,
		MAX(ISNULL(MerchPrizes, '0.00'))		AS MerchPrizes,
		SUM(ISNULL(AccrualIncrease, '0.00'))	AS AccrualIncrease,
		SUM(ISNULL(Tax, '0.00'))                AS Tax,
		SUM(ISNULL(DeviceFee, '0.00'))          AS DeviceFee
FROM 	@Results
GROUP BY ProductName
ORDER BY ProductName	

SET NOCOUNT OFF

END




GO


