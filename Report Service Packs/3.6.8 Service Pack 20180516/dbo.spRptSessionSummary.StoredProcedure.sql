USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummary]    Script Date: 05/15/2018 11:34:11 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummary]    Script Date: 05/15/2018 11:34:11 ******/
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

begin

set nocount on

--------------------------------------------------------------------
-- 2016.04.19 tmp: US4651 - Grouped the sales by product type
-- 2016.04.19 tmp: US4652 - Added the number of voids for each product 
-- 2017.07.10 tmp: In Device Fees, changed to a left join so that if a device fee is
--                 charged but the device id is null the transaction is returned. 
-- 2018.05.15 tmp: If in Nevada report CBB sales by price per card. Outside of Nevada
--                 report the number of products sold and the product price. 
--                 Reporting by price per card causes sales to be overstated if the card count
--                 is greater than 1. 
--------------------------------------------------------------------

--Declare
--    @OperatorID INT,
--    @Session INT,
--    @IncludeConcessions INT,
--    @GamingDate DATETIME,
--    @IncludeMerchandise INT,
--    @IncludePullTabs INT

--Set @OperatorID = 1
--Set @GamingDate = '01/11/2016'
--Set @Session = 2
--Set @IncludeConcessions = 1
--Set @IncludeMerchandise = 1
--Set @IncludePullTabs = 1

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
	ProductType			nvarchar(64),
	ProductName			NVARCHAR(64),
	Quantity			int,
	VoidQuantity		int,
	Sales				money,
	--PaperSales			MONEY,
	ElectronicSales		MONEY,
	BingoOtherSales		MONEY,
	MerchandiseSales    MONEY,
	ConcessionSales     MONEY,
	PullTabSales        MONEY,	
	Discounts           MONEY,
	Coupons				MONEY,
	--CashPrizes			MONEY,
	--MerchPrizes			MONEY,
	--AccrualIncrease		MONEY,
	Tax					MONEY,
	DeviceFee			MONEY,
	ValidationSales		MONEY	-- Add validation sales
)


-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR PAPER SALES
-------------------------------------------------------------

--
-- Insert rows for our Paper Sales (Sales - Returns)
--

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Paper',
		fps.ItemName,		
		sum(fps.Qty),
		SUM(fps.RegisterPaper + fps.FloorPaper)
FROM	dbo.FindPaperSales(@OperatorID, @GamingDate, @GamingDate, @Session) fps
GROUP BY fps.ItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR TAXES
-------------------------------------------------------------

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Sales
)
SELECT	'Sales Tax',
		'Sales Tax',
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
-------------------------------------------------------------
with cte_Receipts (ReceiptId, VoidedReceiptID)
as
(
    select	distinct (rd.RegisterReceiptId),
			rd.VoidedRegisterReceiptID
    from RegisterDetail rd
        join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId
        join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
    where --rd.VoidedRegisterReceiptId is null
       -- and 
        sp.GamingDate = @GamingDate
        and (sp.GamingSession = @Session or @Session = 0)
        and sp.OperatorId = @OperatorId
        and rr.SaleSuccess = 1
)
INSERT INTO @Results
(
    ProductType,
    ProductName,
    Quantity,
    VoidQuantity,
    Sales
)
SELECT	'Device Fees',
		isnull(d.DeviceType, 'Pack'),
--		N'',
		case when VoidedReceiptID is null then count(rr.DeviceFee)
			else 0 end,
		case when VoidedReceiptID is not null then count(rr.DeviceFee)
			else 0 end,	
		case when VoidedReceiptID is null then SUM(ISNULL(rr.DeviceFee,0))
			else 0 end
FROM RegisterReceipt rr
    join cte_Receipts on rr.RegisterReceiptId = ReceiptId
    left join Device d on rr.DeviceID = d.DeviceID		-- 2017.07.10 tmp Changed to left join.
Where rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND isnull(rr.DeviceFee,0)<>0
group by d.DeviceType, VoidedReceiptID;


-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR ELECTRONIC SALES
-------------------------------------------------------------

--
-- Insert rows for our Electronic Sales (Sales - Returns)
--
INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Electronic',
		rdi.ProductItemName,
		sum(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 5 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
GROUP BY rdi.ProductItemName

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
	
)
SELECT	'Electronic',
		rdi.ProductItemName,
		sum(-1 * rd.Quantity * rdi.Qty), 
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID = 5 AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Electronic Crystal Ball Bingo SALES
-------------------------------------------------------------
-- Insert rows for Crystal Ball Bingo (Sales - Returns)
-- If in Nevada report sales by price per card, else report the product sales.

declare @State nvarchar(max)

set @State = (	
				select	a.State
				from	Operator o
						join Address a on o.AddressID = a.AddressID
				where	o.OperatorID = @OperatorID
			 )
			 
If @State = 'NV'
begin
							
	Declare @CBBResults table
	(
		ProductName nvarchar(64),
		Quantity int,
		QuantityVoid int,
		IsQuickPick int,
		ElectronicSales money
	)

	INSERT INTO @CBBResults
	(
		ProductName,
		Quantity,		
		IsQuickPick,
		ElectronicSales
	)
	SELECT	rdi.ProductItemName,
			count(bch.bchIsQuickPick),
			bch.bchIsQuickPick,
			SUM(rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN (Select Distinct bchMasterCardNo, bchRegisterDetailItemID, bchIsQuickPick From BingoCardHeader) as bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID) --DE10983
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	WHERE	rr.GamingDate = @GamingDate AND
			rr.SaleSuccess = 1 AND
			rr.TransactionTypeID = 1 AND
			rr.OperatorID = @OperatorID AND
			rdi.ProductTypeID IN (1, 2, 3, 4) AND
			sp.GamingSession = @Session AND
			rd.VoidedRegisterReceiptID IS NULL AND
			(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
	GROUP BY bch.bchIsQuickPick, rdi.ProductItemName

	INSERT INTO @CBBResults
	(
		ProductName,
		Quantity,		
		IsQuickPick,
		ElectronicSales
	)
	SELECT	rdi.ProductItemName,
			count(bch.bchIsQuickPick),
			bch.bchIsQuickPick,
			SUM(-1 * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN (Select Distinct bchMasterCardNo, bchRegisterDetailItemID, bchIsQuickPick From BingoCardHeader) as bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID) --DE10983
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	WHERE	rr.GamingDate = @GamingDate AND
			rr.SaleSuccess = 1 AND
			rr.TransactionTypeID = 3 AND		-- Returns
			rr.OperatorID = @OperatorID AND
			rdi.ProductTypeID IN (1, 2, 3, 4) AND
			sp.GamingSession = @Session AND
			rd.VoidedRegisterReceiptID IS NULL AND
			(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
	GROUP BY bch.bchIsQuickPick, rdi.ProductItemName

	---- CBB Voids ---------------------------------------------------------
	INSERT INTO @CBBResults
	(
		ProductName,
		QuantityVoid,		
		IsQuickPick
	)
	SELECT	rdi.ProductItemName,
			count(bch.bchIsQuickPick),
			bch.bchIsQuickPick
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN (Select Distinct bchMasterCardNo, bchRegisterDetailItemID, bchIsQuickPick From BingoCardHeader) as bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID) --DE10983
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	WHERE	rr.GamingDate = @GamingDate AND
			rr.SaleSuccess = 1 AND
			rr.TransactionTypeID = 1 AND
			rr.OperatorID = @OperatorID AND
			rdi.ProductTypeID IN (1, 2, 3, 4) AND
			sp.GamingSession = @Session AND
			rd.VoidedRegisterReceiptID IS NOT NULL AND
			(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
	GROUP BY bch.bchIsQuickPick, rdi.ProductItemName

	Update @CBBResults
	Set ProductName = ProductName + ' ' + '(QP)'
	Where IsQuickPick = 1

	Update @CBBResults
	Set ProductName = ProductName + ' ' + '(HP)'
	Where IsQuickPick = 0

	Insert @Results
	(
		ProductType,
		ProductName,
		Quantity,
		VoidQuantity,
		Sales
	)	
	Select	'Electronic',
			ProductName,
			sum(Quantity),
			sum(QuantityVoid),
			sum(ElectronicSales)
	From @CBBResults
	group by ProductName
end
else 
	INSERT INTO @Results
		(
			ProductType,
			ProductName,
			Quantity,
			Sales
		)
		SELECT	'Electronic',
				rdi.ProductItemName,
				sum(rd.Quantity * rdi.Qty),
				SUM(rd.Quantity * rdi.Qty * rdi.Price)
		FROM RegisterReceipt rr
			JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
			JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
			JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		WHERE	rr.GamingDate = @GamingDate AND
				rr.SaleSuccess = 1 AND
				rr.TransactionTypeID = 1 AND
				rr.OperatorID = @OperatorID AND
				rdi.ProductTypeID in (1,2,3,4) AND
				sp.GamingSession = @Session AND
				rd.VoidedRegisterReceiptID IS NULL AND
				(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
		GROUP BY rdi.ProductItemName

		INSERT INTO @Results
		(
			ProductType,
			ProductName,
			Quantity,
			Sales
			
		)
		SELECT	'Electronic',
				rdi.ProductItemName,
				sum(-1 * rd.Quantity * rdi.Qty), 
				SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
		FROM RegisterReceipt rr
			JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
			JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
			JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		WHERE	rr.GamingDate = @GamingDate AND
				rr.SaleSuccess = 1 AND
				rr.TransactionTypeID = 3 AND -- Return
				rr.OperatorID = @OperatorID AND
				rdi.ProductTypeID in (1,2,3,4) AND
				sp.GamingSession = @Session AND
				rd.VoidedRegisterReceiptID IS NULL AND
				(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
		GROUP BY rdi.ProductItemName
		
		INSERT INTO @Results
		(
			ProductType,
			ProductName,
			VoidQuantity
		)
		SELECT	'Electronic',
				rdi.ProductItemName,
				sum(rd.Quantity * rdi.Qty) 
		FROM RegisterReceipt rr
			JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
			JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
			JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		WHERE	rr.GamingDate = @GamingDate AND
				rr.SaleSuccess = 1 AND
				rr.TransactionTypeID = 1 AND -- Sold
				rr.OperatorID = @OperatorID AND
				rdi.ProductTypeID in (1,2,3,4) AND
				sp.GamingSession = @Session AND
				rd.VoidedRegisterReceiptID IS NOT NULL AND
				(rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
		GROUP BY rdi.ProductItemName

 

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Bingo Other SALES, Merchandise, Concessions, Pulltabs
-------------------------------------------------------------
INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	p.ProductType,
		rdi.ProductItemName,
		sum(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join ProductType p on rdi.ProductTypeID = p.ProductTypeID
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID in (6, 7, 14, 17) AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		NOT rdi.ProductItemName LIKE 'Discount%'
GROUP BY p.ProductType,
		rdi.ProductItemName

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	p.ProductType,
		rdi.ProductItemName,
		sum(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join ProductType p on rdi.ProductTypeID = p.ProductTypeID
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 3 AND -- Return
		rr.OperatorID = @OperatorID AND
		rdi.ProductTypeID in (6, 7, 14, 17) AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NULL AND
		NOT rdi.ProductItemName LIKE 'Discount%'
GROUP BY p.ProductType, 
		rdi.ProductItemName
-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Merchandise
-------------------------------------------------------------

--
-- Insert rows for our Merchandise Sales (Sales - Returns)
--
--INSERT INTO @Results
--(
--	ProductName,
--	MerchandiseSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(rd.Quantity * rdi.Qty * rdi.Price)
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 1 AND
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 7 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

--INSERT INTO @Results
--(
--	ProductName,
--	MerchandiseSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 3 AND -- Return
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 7 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Concessions
-------------------------------------------------------------

--
-- Insert rows for our Concession Sales (Sales - Returns)
--
--INSERT INTO @Results
--(
--	ProductName,
--	ConcessionSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(rd.Quantity * rdi.Qty * rdi.Price)
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 1 AND
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 6 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

--INSERT INTO @Results
--(
--	ProductName,
--	ConcessionSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 3 AND -- Return
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 6 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR PullTabSales
-------------------------------------------------------------

--
-- Insert rows for our PullTabSales Sales (Sales - Returns)
--
--INSERT INTO @Results
--(
--	ProductName,
--	PullTabSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(rd.Quantity * rdi.Qty * rdi.Price)
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 1 AND
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 17 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

--INSERT INTO @Results
--(
--	ProductName,
--	PullTabSales
--)
--SELECT	rdi.ProductItemName,
--		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
		
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE	rr.GamingDate = @GamingDate AND
--		rr.SaleSuccess = 1 AND
--		rr.TransactionTypeID = 3 AND -- Return
--		rr.OperatorID = @OperatorID AND
--		rdi.ProductTypeID = 17 AND
--		sp.GamingSession = @Session AND
--		rd.VoidedRegisterReceiptID IS NULL 
--GROUP BY rdi.ProductItemName

-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR Discounts
-------------------------------------------------------------


-- Include discounts into discounts

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Discounts',
		isnull(rd.PackageReceiptText, dt.DiscountTypeName),
--		dt.DiscountTypeName,
		sum(rd.Quantity),
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
GROUP BY  rd.PackageReceiptText, dt.DiscountTypeName

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Discounts',
		isnull(rd.PackageReceiptText, dt.DiscountTypeName),
		--dt.DiscountTypeName,
		sum(rd.Quantity),
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
GROUP BY rd.PackageReceiptText, dt.DiscountTypeName

---- Voided Discounts
INSERT INTO @Results
(
	ProductType,
	ProductName,
	VoidQuantity
)
SELECT	'Discounts',
		isnull(rd.PackageReceiptText, dt.DiscountTypeName),
--		dt.DiscountTypeName,
		sum(rd.Quantity)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join DiscountTypes dt on (dt.DiscountTypeID = rd.DiscountTypeID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		sp.GamingSession = @Session AND
		rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY  rd.PackageReceiptText, dt.DiscountTypeName

--Hacked discounts
INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Discounts',
		rdi.ProductItemName,
		sum(rd.Quantity * rdi.Qty),
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
	ProductType,
	ProductName,
	Quantity,
	Sales
)
SELECT	'Discounts',
		rdi.ProductItemName,
		sum(-1 * rd.Quantity * rdi.Qty),
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

INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity
)
SELECT	'Discounts',
		rdi.ProductItemName,
		sum(-1 * rd.Quantity * rdi.Qty)
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
		rd.VoidedRegisterReceiptID IS NOT NULL AND
		rdi.ProductItemName LIKE 'Discount%'
GROUP BY rdi.ProductItemName


------------------------------------------------
-- BEGIN CALCULATIONS FOR COUPON
------------------------------------------------
INSERT INTO @Results
(
	ProductType,
	ProductName,
	Quantity,
	VoidQuantity,
	Sales
)

Select	'Coupon',
		CouponName,
		sum(QuantityNet), 
		sum(QuantityVoided),
		sum(NetSales)
From dbo.FindCouponSales(@OperatorID, @GamingDate, @GamingDate, @Session)
Group By CouponName

------------------------------------------------
-- Begine calculations for validations
------------------------------------------------
insert into @Results
(
	ProductType,
	ProductName,
	Quantity,
	Sales
)
Select	'Validation',
		ItemName,
		sum(Qty),
		SUM(Total)
From dbo.FindValidationSales (@OperatorID, @GamingDate, @GamingDate, @Session)
Group By ItemName

--- Count the number of validated packs that were voided
--insert @Results
--(
--	ProductType,
--	ProductName,
--	VoidQuantity
--)
--select	'Validations',
--		rdi.ProductItemName,
--		sum(rd.Quantity * rdi.Qty * rdi.Validated)    [Total]
--from RegisterReceipt rr
--	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
--	join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
--where 
--	rr.GamingDate = @GamingDate
--	and rr.SaleSuccess = 1
--	and rr.TransactionTypeID = 1
--	and rr.OperatorID = @OperatorID
--	and sp.GamingSession = @Session
--	and rd.VoidedRegisterReceiptID is not null
--	and rdi.Validated is not null
--	and rdi.ProductTypeID = 18		
--group by rdi.ProductItemName



-------------------------------------------------------------
-- BEGIN CALCULATIONS FOR CASH PRIZES AND MERCHANDISE PRIZES
-------------------------------------------------------------
--DECLARE @PayoutIDPerSGPID TABLE
--(
--	PayoutTransID			INT,
--	SessionGamesPlayedID	INT,
--	GameCategoryID			INT,
--	CashPayoutAmount		MONEY,
--	MerchPayoutAmount		MONEY
--)

--
-- The next few sections match up a payout id to the corresponding sessiongamesplayedid
--

--INSERT INTO @PayoutIDPerSGPID
--SELECT   
--	  pt.PayoutTransID
--	 ,sgp.SessionGamesPlayedID
--	 ,0
--	 ,'0.00'
--	 ,'0.00'
--FROM 
--	PayoutTrans pt
--	JOIN PayoutTransBingoCustom ptbc ON (pt.PayoutTransID = ptbc.PayoutTransID)
--	JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
--	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
--WHERE	
--	@GamingDate = sp.GamingDate AND
--	@Session = sp.GamingSession AND
--	@OperatorID = sp.OperatorID AND
--	pt.TransTypeID = 36 AND
--	pt.VoidTransID IS NULL
	
--INSERT INTO @PayoutIDPerSGPID
--SELECT   
--	  pt.PayoutTransID
--	 ,sgp.SessionGamesPlayedID
--	 ,0
--	 ,'0.00'
--	 ,'0.00'
--FROM 
--	PayoutTrans pt
--	JOIN PayoutTransBingoGame ptbg ON (pt.PayoutTransID = ptbg.PayoutTransID)
--	JOIN SessionGamesPlayed sgp ON (ptbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
--	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
--WHERE	
--	@GamingDate = sp.GamingDate AND
--	@Session = sp.GamingSession	AND
--	@OperatorID = sp.OperatorID AND
--	pt.TransTypeID = 36 AND
--	pt.VoidTransID IS NULL
	
--INSERT INTO @PayoutIDPerSGPID
--SELECT   
--	  pt.PayoutTransID
--	 ,sgp.SessionGamesPlayedID
--	 ,0
--	 ,'0.00'
--	 ,'0.00'
--FROM 
--	PayoutTrans pt
--	JOIN PayoutTransBingoGoodNeighbor ptbg ON (pt.PayoutTransID = ptbg.PayoutTransID)
--	JOIN SessionGamesPlayed sgp ON (ptbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
--	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
--WHERE	
--	@GamingDate = sp.GamingDate AND
--	@Session = sp.GamingSession	AND
--	@OperatorID = sp.OperatorID AND
--	pt.TransTypeID = 36 AND
--	pt.VoidTransID IS NULL
	
--INSERT INTO @PayoutIDPerSGPID
--SELECT   
--	  pt.PayoutTransID
--	 ,sgp.SessionGamesPlayedID
--	 ,0
--	 ,'0.00'
--	 ,'0.00'
--FROM 
--	PayoutTrans pt
--	JOIN PayoutTransBingoRoyalty ptbr ON (pt.PayoutTransID = ptbr.PayoutTransID)
--	JOIN SessionGamesPlayed sgp ON (ptbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
--	JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
--WHERE	
--	@GamingDate = sp.GamingDate AND
--	@Session = sp.GamingSession	AND
--	@OperatorID = sp.OperatorID	AND
--	pt.TransTypeID = 36 AND
--	pt.VoidTransID IS NULL AND
--	pt.AccrualTransID IS NULL -- DE9994 Exclude accrual payouts
	
--
-- For each payoutTrans, add up the Cash and Merc payout amount
--	
--UPDATE @PayoutIDPerSGPID
--SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.DefaultAmount, '0.00')), '0.00')
--											FROM PayoutTransDetailCash ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

--UPDATE @PayoutIDPerSGPID
--SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.DefaultAmount, '0.00')), '0.00')
--											FROM PayoutTransDetailCheck ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

--UPDATE @PayoutIDPerSGPID
--SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.Refundable, '0.00')), '0.00')
--											FROM PayoutTransDetailCredit ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

--UPDATE @PayoutIDPerSGPID
--SET CashPayoutAmount = CashPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.NonRefundable, '0.00')), '0.00')
--											FROM PayoutTransDetailCredit ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

--UPDATE @PayoutIDPerSGPID
--SET MerchPayoutAmount = MerchPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.PayoutValue, '0.00')), '0.00')
--											FROM PayoutTransDetailMerchandise ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

--UPDATE @PayoutIDPerSGPID
--SET MerchPayoutAmount = MerchPayoutAmount + (SELECT ISNULL(SUM(ISNULL(ptdc.PayoutValue, '0.00')), '0.00')
--											FROM PayoutTransDetailOther ptdc
--											WHERE ptdc.PayoutTransID = pips.PayoutTransID)
--FROM @PayoutIDPerSGPID pips

----
---- Update the game category for each game
----
--UPDATE @PayoutIDPerSGPID
--SET GameCategoryID =   (SELECT sgp.GameCategoryID
--						FROM SessionGamesPlayed sgp
--						WHERE SessionGamesPlayedID = pips.SessionGamesPlayedID)
--FROM @PayoutIDPerSGPID pips						

--
-- Get the payouts per game category
--
--DECLARE @PayoutAmountPerCategory TABLE
--(
--	GameCategoryID	INT
--	,CashAmount		MONEY
--	,MercAmount		MONEY
--)

--INSERT INTO @PayoutAmountPerCategory
--SELECT 
--	GameCategoryID
--	,SUM(CashPayoutAmount)
--	,SUM(MerchPayoutAmount)
--FROM @PayoutIDPerSGPID
--GROUP BY GameCategoryID

--
-- Get the products tied to each game category
--
--DECLARE @ProdsPerCategory TABLE
--(
--	ProductItemName		NVARCHAR(64),
--	GameCategoryID		INT
--)

--INSERT INTO @ProdsPerCategory 
--SELECT
--	rdi.ProductItemName,
--	rdi.GameCategoryID
--FROM 
--	RegisterDetailItems rdi
--	JOIN RegisterDetail rd ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
--WHERE 
--	GameCategoryID IS NOT NULL AND
--	@GamingDate = sp.GamingDate AND
--	@Session = sp.GamingSession	AND
--	@OperatorID = sp.OperatorID
	
--DECLARE @DistinctProdsPerCategory TABLE
--(
--	ProductItemName		NVARCHAR(64),
--	GameCategoryID		INT
--)	

--INSERT INTO @DistinctProdsPerCategory
--SELECT DISTINCT ProductItemName, GameCategoryID
--FROM @ProdsPerCategory

--
-- Loop through each product/category combination
-- and give some of the payout to each product
--
--DECLARE @CursorProductItemName NVARCHAR(64),
--		@CursorGameCategoryID  INT,
--		@NumProductsWithCat		INT

--DECLARE SessionSummaryCursor CURSOR LOCAL FOR
--		SELECT ProductItemName, GameCategoryID
--		FROM @DistinctProdsPerCategory
			
--OPEN SessionSummaryCursor
--FETCH NEXT FROM SessionSummaryCursor INTO @CursorProductItemName, @CursorGameCategoryID

--WHILE @@FETCH_STATUS = 0
--BEGIN
--	--
--	-- Get the number of distinct products that were used with this cat
--	--
--	SET @NumProductsWithCat = (SELECT COUNT(*)
--							   FROM @DistinctProdsPerCategory
--							   WHERE GameCategoryID = @CursorGameCategoryID)
							   
							   
--	UPDATE @Results
--	SET CashPrizes = ISNULL(CashPrizes, '0.00') + ISNULL((SELECT CashAmount
--								                          FROM @PayoutAmountPerCategory
--								                          WHERE GameCategoryID = @CursorGameCategoryID), '0.00') / @NumProductsWithCat,
--	MerchPrizes = ISNULL(MerchPrizes, '0.00') + ISNULL((SELECT MercAmount
--															FROM @PayoutAmountPerCategory
--								                            WHERE GameCategoryID = @CursorGameCategoryID), '0.00') / @NumProductsWithCat
--	WHERE ProductName = @CursorProductItemName							   
								   	
	
--	FETCH NEXT FROM SessionSummaryCursor INTO @CursorProductItemName, @CursorGameCategoryID
--END
--CLOSE SessionSummaryCursor
--DEALLOCATE SessionSummaryCursor	

------ Voids ----------------------------------------------------------------
Insert into @Results
(
		ProductType,
		ProductName,
		VoidQuantity
)
SELECT	pt.ProductType,
		rdi.ProductItemName,
		sum(rd.Quantity * rdi.Qty)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join ProductType pt on rdi.ProductTypeID = pt.ProductTypeID
WHERE	rr.GamingDate = @GamingDate AND
		rr.SaleSuccess = 1 AND
		rr.TransactionTypeID = 1 AND
		rr.OperatorID = @OperatorID AND
		sp.GamingSession = @Session and
		rd.VoidedRegisterReceiptID IS not NULL and
		rdi.ProductTypeID not in (1, 2, 3, 4)
GROUP BY pt.ProductType,
		rdi.ProductItemName


--
-- Select out our result outputs
--
SELECT 	ProductType,
		ProductName,
		sum(isnull(Quantity, 0))				as Quantity,
		sum(isnull(VoidQuantity, 0))			as VoidQuantity,
		sum(isnull(Sales, '0.00'))				as Sales
		--SUM(ISNULL(PaperSales, '0.00'))			AS PaperSales,
		--SUM(ISNULL(ElectronicSales, '0.00'))	AS ElectronicSales,
		--SUM(ISNULL(BingoOtherSales, '0.00'))	AS BingoOtherSales,
		--SUM(ISNULL(ConcessionSales, '0.00'))    AS ConcessionSales,
		--SUM(ISNULL(MerchandiseSales, '0.00'))   AS MerchandiseSales,
		--SUM(ISNULL(PullTabSales, '0.00'))       AS PullTabSales,
		--SUM(ISNULL(Discounts, '0.00'))          AS Discounts,
		--SUM(ISNULL(Coupons, '0.00'))            AS Coupons,
		--MAX(ISNULL(CashPrizes, '0.00'))			AS CashPrizes,
		--MAX(ISNULL(MerchPrizes, '0.00'))		AS MerchPrizes,
		--SUM(ISNULL(AccrualIncrease, '0.00'))	AS AccrualIncrease,
		--SUM(ISNULL(Tax, '0.00'))                AS Tax,
		--SUM(ISNULL(DeviceFee, '0.00'))          AS DeviceFee,
		--SUM(ISNULL(ValidationSales, '0.00'))	AS ValidationSales
FROM 	@Results
where	( Quantity <> 0 
		and Sales <> 0.00
		)
		or VoidQuantity <> 0
GROUP BY ProductType,
		ProductName
ORDER BY ProductType, 
		ProductName	
		
set nocount off

end



GO

