USE [Daily]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spRptMiccosukeeCashActivityReport') AND type IN (N'P', N'PC')) 
DROP PROCEDURE [dbo].[spRptMiccosukeeCashActivityReport]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptMiccosukeeCashActivityReport] 
-- =============================================
-- Author:		Travis Pollock
-- Description:	<>
--
-- Copied from spRptCashActivityReport
-- 20190506: Miccosukee version of the Cash Activity Report
--           Seperated Drops and Bank Close transactions.
--=============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@StaffID	AS INT,
	@Session	AS INT 
AS

SET NOCOUNT ON;
-- Cash Activity Report

-- Temp table
declare @CashActivity table
(
	productItemName		NVARCHAR(128),
	staffIdNbr          int,            -- DE7731
	staffLastName       NVARCHAR(64),
	staffFirstName      NVARCHAR(64),
	price               money,          -- DE7731
	gamingDate          datetime,       -- DE7731
	sessionNbr          int,            -- DE7731
	itemQty				INT,
	merchandise			MONEY,
	paper				MONEY,          -- original field, represents paper sales made at a register
	paperSalesFloor 	MONEY,          -- DE7731
	paperSalesTotal 	MONEY,          -- DE7731
	electronic			MONEY,
	credit				MONEY,
	discount			MONEY,
	coupon			MONEY,
	other				MONEY
	, bingoPayouts money
	, accrualPayouts money
	, pullTabPayouts money
	, Taxes money
	, Fees  money
    , BanksIssuedTo MONEY
    , BanksIssuedFrom MONEY
    , DropsTo MONEY
    , TotalDrop MONEY
	, pullTabSales money
	, BankType int
	, prizeFees MONEY
	, DropsFrom	money
);

/* Start 2017.04.24
--		
-- Insert Merchandise Rows		
--
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,    
		electronic,
		credit,
		discount,
		other
		, bingoPayouts
		, pullTabPayouts
		, accrualPayouts
		, prizeFees 
		, BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,   -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, 0, 0, 0, 0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID    	
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID = 7
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731


-- And take out returns
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, 0, 0,0,0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID = 7
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
GROUP BY rdi.ProductItemName,
	rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731
*/

--
-- Merchandise sales: both register sales and inventory (floor sales)
-- 
insert @CashActivity
(
	productItemName
	, staffIdNbr
	, staffLastName
	, staffFirstName
	, price
	, gamingDate
	, sessionNbr
	, itemQty
	, merchandise
	, paper
	, paperSalesFloor
	, paperSalesTotal
	, electronic
	, credit
	, discount
	, other
	, bingoPayouts
	, pullTabPayouts
	, Taxes
	, Fees
    , BanksIssuedTo 
    , BanksIssuedFrom 
    , DropsTo 
    , TotalDrop 
	, pullTabSales
	, BankType
	, accrualPayouts 
	, prizeFees
	
)
select 
	 ItemName
	, fms.StaffID
	, s.LastName
	, s.FirstName
	, Price
	, GamingDate
	, SessionNo
	, Qty
	, RegisterMerch + FloorMerch
	, 0
	, 0
	, 0
	, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,2,0,0
from FindMerchSales(@OperatorID, @StartDate, @EndDate, @Session) fms
	join Staff s on fms.StaffID = s.StaffID
where (@StaffID = 0 or s.StaffID = @StaffID)
	and s.LoginNumber > 0
-- End 2017.04.24

--		
-- Insert Electronic Rows		
--
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName,
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0, 0.0, 0.0, --paper,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0 --other,
		, 0, 0, 0, 0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName; 

INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName,
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0,0.0,0.0, --paper,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0 --other,
		, 0, 0, 0, 0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName; 

--		
-- Insert Credit Rows		
--
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, 0, 0,0, 0, 2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID BETWEEN 10 AND 13
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731

INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, 0, 0, 0, 0, 2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID BETWEEN 10 AND 13
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731


--		
-- Insert Discount Rows		
--
-- DE7731: treat discounts like sales
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, 0, 0, 0, 0, 2  -- bingo and pulltab payouts		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID = 14	AND RDI.ProductItemName LIKE 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731

INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, 0, 0, 0, 0, 2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID = 14 and rdi.ProductItemName like 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731


-- FIX DE7719: Restore original discounts as well as new product-name discounts
--		
-- Insert Discount Rows		
--
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
SELECT	dt.DiscountTypeName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName, s.FirstName,                     
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),
		0.00,
		0.00, 0, 0, 0, 2
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY dt.DiscountTypeName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;

INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
SELECT	dt.DiscountTypeName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName, s.FirstName,                     
		SUM(-1 * rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1??????????????
		0.00,
		0.00, 0, 0, 0, 2
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID)
	left join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY dt.DiscountTypeName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName; 
-- END FIX DE7719


--Coupon
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		coupon,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)

SELECT	
rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		sum(rd.Quantity * rd.PackagePrice),
		0.00
		, 0, 0, 0, 0, 2  -- bingo and pulltab payouts		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	left JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
	Join CompAward ca on rd.CompAwardID = ca.CompAwardID
	left Join Comps c on ca.CompID = c.CompID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731


INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		coupon,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)

SELECT	
rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		sum(rd.Quantity * rd.PackagePrice),
		0.00
		, 0, 0, 0, 0, 2  -- bingo and pulltab payouts		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	left JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
	Join CompAward ca on rd.CompAwardID = ca.CompAwardID
	left Join Comps c on ca.CompID = c.CompID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731

--		
-- Insert Other Rows and Validation Rows		
--
INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731, US1850
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
		, 0, 0,0, 0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 18, 19) /*US4515 Added 18 US5361 Added 19*/ or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731

INSERT INTO @CashActivity
	(
		productItemName,
		staffIdNbr,
		price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)
SELECT	rdi.ProductItemName, 
		rr.StaffID,
		rdi.Price, rr.GamingDate
		, isnull(convert(int, sp.GamingSession), -1)
		, s.LastName , s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
		, 0, 0,0, 0,2  -- bingo and pulltab payouts
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 18, 19) /*US4515 Added 18 US5361 Added 19*/ or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rdi.ProductItemName, rr.StaffID,
	rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName;         -- DE7731


--
-- Add in the pull tab sales records
--
INSERT INTO @CashActivity
	(
		gamingDate,
		sessionNbr,
        staffIdNbr,
		StaffLastName,
		StaffFirstName,
		PullTabSales
		, ProductItemName
		, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount,other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)
select 
	GamingDate
	, SessionNo
	, fpts.StaffID
	, s.LastName
	, s.FirstName
	, fpts.FloorPulltab + fpts.RegisterPulltab
	, ItemName
	, Qty
	, 0
	, 0
	, 0
	, 0
	, 0, 0, 0, 0, 0, 0, 0, 0, 2
from FindPulltabSales(@OperatorID, @StartDate, @EndDate, @Session) fpts
	join Staff s on fpts.StaffID = s.StaffID
where (@StaffID = 0 or s.StaffID = @StaffID)
	and s.LoginNumber > 0
--SELECT	rr.GamingDate,
--		isnull(convert(int, sp.GamingSession), -1),
--        s.StaffID,
--		s.LastName,
--		s.FirstName,
--		SUM(rd.Quantity * rdi.Qty * rdi.Price)
--		, rdi.ProductItemName
--		, 0,0,0,0,0,0,0,0,0,0,0,0, 0,2
--FROM RegisterReceipt rr		
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--	JOIN Staff s ON (s.StaffID = rr.StaffID)
--WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
--	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
--	AND rr.SaleSuccess = 1
--	AND rr.TransactionTypeID = 1
--	AND rr.OperatorID = @OperatorID
--	AND rdi.ProductTypeID IN (17)
--	AND (@Session = 0 or sp.GamingSession = @Session)
--	AND rd.VoidedRegisterReceiptID IS NULL	
--    and (@StaffID = 0 or rr.StaffID = @StaffID)
--    and s.LoginNumber > 0
--GROUP BY rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rdi.ProductItemName;

--INSERT INTO @CashActivity
--	(
--		gamingDate,
--		sessionNbr,
--        staffIdNbr,
--		StaffLastName,
--		StaffFirstName,
--		PullTabSales
--        , ProductItemName
--		, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount,other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
--	)
--SELECT	rr.GamingDate,
--		isnull(convert(int, sp.GamingSession), -1),
--        s.StaffID,
--		s.LastName,
--		s.FirstName,
--		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
--		, rdi.ProductItemName
--		, 0,0,0,0,0,0,0,0,0,0,0,0,0,2
--FROM RegisterReceipt rr		
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--	JOIN Staff s ON (s.StaffID = rr.StaffID)
--WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
--	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
--	AND rr.SaleSuccess = 1
--	and rr.TransactionTypeID = 3 -- Return
--	AND rr.OperatorID = @OperatorID
--	AND rdi.ProductTypeID IN (17)
--	AND (@Session = 0 or sp.GamingSession = @Session)
--	AND rd.VoidedRegisterReceiptID IS NULL	
--    and (@StaffID = 0 or rr.StaffID = @StaffID)
--    and s.LoginNumber > 0
--GROUP BY rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rdi.ProductItemName;



--
-- Taxes
--
INSERT INTO @CashActivity
	(
		gamingDate,
		sessionNbr,
        staffIdNbr,
		staffLastName, staffFirstName,
		Taxes
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees,BankType
	)   
SELECT	
    rr.GamingDate,
	isnull(convert(int, sp.GamingSession), -1),
    s.StaffID, s.LastName, s.FirstName,
	SUM(rd.SalesTaxAmt * rd.Quantity) 
	, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN Staff s ON (s.StaffID = rr.StaffID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID IN (1, 3)
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL	
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0
GROUP BY rr.GamingDate, sp.GamingSession,
	s.StaffID, s.LastName, s.FirstName;


--
-- FEES
--
INSERT INTO @CashActivity
	(
		gamingDate,
		sessionNbr,
        staffIdNbr,
		staffLastName, staffFirstName,
		Fees
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees, BankType
	)    	
SELECT	rr.GamingDate,
	(SELECT TOP 1 ISNULL(convert(int,sp2.GamingSession), -1) FROM RegisterReceipt rr2
		JOIN RegisterDetail rd2 ON (rr2.RegisterReceiptID = rd2.RegisterReceiptID)
		LEFT JOIN SessionPlayed sp2 ON (sp2.SessionPlayedID = rd2.SessionPlayedID)
		WHERE rr2.RegisterReceiptID = rr.RegisterReceiptID
		ORDER BY sp2.GamingSession),
    s.StaffID, s.LastName, s.FirstName,
	isnull(rr.DeviceFee, 0)
    , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,2 
FROM RegisterReceipt rr
	JOIN Staff s ON (s.StaffID = rr.StaffID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rr.DeviceFee IS NOT NULL
	AND rr.DeviceFee <> 0 
	AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and s.LoginNumber > 0


--		
-- Insert Payout Rows		
-- At this point since this is the "Cash Activity" report, assume only
-- cash payouts are accounted for.
--
DECLARE @TmpPayouts TABLE
(
	PayoutTransID		INT,
	StaffID				INT,
	GamingDate			SMALLDATETIME,
	GamingSession		TINYINT,
	PayoutAmount		MONEY,
	AccrualTransID      INT,
	PrizeFee			MONEY
);

INSERT INTO @TmpPayouts
(
	PayoutTransID
	,StaffID
	,GamingDate
	,GamingSession
	,PayoutAmount
	,AccrualTransID
	,PrizeFee
)
SELECT	 pt.PayoutTransID
		,pt.StaffID
		,pt.GamingDate
		,0
		,ptdc.DefaultAmount
		,pt.AccrualTransID
		,pt.PrizeFee
FROM PayoutTransDetailCash ptdc
	JOIN PayoutTrans pt ON (ptdc.PayoutTransID = pt.PayoutTransID)
	JOIN Staff s ON (pt.StaffID = s.StaffID)
WHERE	pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (pt.OperatorID = @OperatorID OR @OperatorID = 0 OR @OperatorID IS NULL)
	AND (pt.StaffID = @StaffID OR @StaffID = 0 OR @StaffID IS NULL)
	AND pt.VoidTransID IS NULL; -- Not Voided
	
--	
-- Update the session number for the bingo payout
--
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoCustom ptbc ON (ptbc.PayoutTransID = tps.PayoutTransID)
JOIN SessionPlayed sp ON (ptbc.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoCustom
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionPlayedID IS NOT NULL);
				
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoGame ptbg ON (ptbg.PayoutTransID = tps.PayoutTransID)
JOIN SessionPlayed sp ON (ptbg.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoGame
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionPlayedID IS NOT NULL);	
				
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoCustom ptbc ON (ptbc.PayoutTransID = tps.PayoutTransID)
JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoCustom
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionGamesPlayedID IS NOT NULL);		
				
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoGame ptbc ON (ptbc.PayoutTransID = tps.PayoutTransID)
JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoGame
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionGamesPlayedID IS NOT NULL);				
				
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoGoodNeighbor ptbc ON (ptbc.PayoutTransID = tps.PayoutTransID)
JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoGoodNeighbor
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionGamesPlayedID IS NOT NULL);		
				
UPDATE @TmpPayouts
SET GamingSession = sp.GamingSession
FROM @TmpPayouts tps
JOIN PayoutTransBingoRoyalty ptbc ON (ptbc.PayoutTransID = tps.PayoutTransID)
JOIN SessionGamesPlayed sgp ON (ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID)
JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
WHERE EXISTS (SELECT ID
			  FROM PayoutTransBingoRoyalty
			  WHERE PayoutTransID = tps.PayoutTransID
				AND SessionGamesPlayedID IS NOT NULL);															

-- Insert our new results into our response table
INSERT INTO @CashActivity
(
		staffIdNbr
		,staffLastName
		,staffFirstName
		,gamingDate
		,sessionNbr
		,bingoPayouts
		,accrualPayouts
		,prizeFees
		,BankType
)
SELECT	 tp.StaffID
		,s.LastName
		,s.FirstName
		,tp.GamingDate
		,tp.GamingSession
		,CASE WHEN tp.AccrualTransID IS NULL THEN tp.PayoutAmount ELSE 0.0 END
		,CASE WHEN tp.AccrualTransID IS NOT NULL THEN tp.PayoutAmount ELSE 0.0 END
		,PrizeFee
		,2
FROM @TmpPayouts tp
	JOIN Staff s ON (tp.StaffID = s.StaffID)
WHERE	(@StaffID = 0 or tp.StaffID = @StaffID)
    AND (@Session = 0 OR @Session IS NULL OR @Session = tp.GamingSession);


-------------------------------------------------------
-- Banks
-------------------------------------------------------

declare @CashMethod int;
select @CashMethod = CashMethodID from Operator
where OperatorID = @OperatorID;

-- FIX DE8853
-- Money Center mode have true Master and Staff Banks.  Show only staff banks here (original code).
if(@CashMethod = 3)
begin

-- Get banks issued to our staff member
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	BanksIssuedTo,
	BankType,
	price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;

-- Get banks issued from our staff member
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	BanksIssuedFrom,
	BankType,
	price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts,prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;

-- Get banks dropped to our staff member
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	DropsTo,
	BankType
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank closes
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;


-- Get banks closed from our staff member
insert into @CashActivity
(
    GamingDate,
    sessionNbr,
    staffIdNbr,
    staffLastName, staffFirstName,
    TotalDrop,       -- Named "Total Drop" on report, but represents drops from...
    BankType
)
SELECT	
	ct.ctrGamingDate,
	ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,
	SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)) [TotalDrop],
	b.bkBankTypeID
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (20) -- Bank Closes (implicit drops)
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;

-- Get banks dropped
insert into @CashActivity
(
    GamingDate,
    sessionNbr,
    staffIdNbr,
    staffLastName
	, staffFirstName
    , DropsFrom       
    , BankType
)
SELECT	
	ct.ctrGamingDate,
	ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,
	SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)) [TotalDrop],
	b.bkBankTypeID
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID = 29 -- Drops 
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;


end		-- end Money Center Mode
else if (@CashMethod = 1)	-- POS mode
begin
-- POS has master banks assigned to a staff member (even if they don't realize it), but do NOT show drops on the report!

-- Get banks issued to our staff member
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	BanksIssuedTo,
	BankType
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
	--left join StaffPositions sps on b.bkStaffID = sps.StaffID
	--left join Position p on (sps.PositionID = p.PositionID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;
	
	
-- Get Adjust Bank Amount in staff(POS)
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	BanksIssuedTo,
	BankType
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal*-1, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (29) -- Drops
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;	

-- Get banks issued from our staff member
INSERT INTO @CashActivity
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	BanksIssuedFrom,
	BankType
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)),
		b.bkBankTypeID
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	and s.LoginNumber > 0
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,
	s.StaffID, s.LastName, s.FirstName,b.bkBankTypeID;


end					-- end POS Mode

else if (@CashMethod = 2)	-- MACHINE mode

begin
-- Machine Mode have no master banks (Master is for staffid = 0). so remove filter in order to show all banks

	-- Get banks issued to our staff member
	INSERT INTO @CashActivity
	(
		gamingDate, 
		sessionNbr,
		staffIdNbr,
		staffLastName,
		staffFirstName,
		BanksIssuedTo,
		BankType
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
	)
	SELECT	ct.ctrGamingDate,
			ct.ctrGamingSession,
			b.bkStaffID, 'Bank', 'Master',
			SUM(ISNULL(ctd.ctrdDefaultTotal, 0)),
			b.bkBankTypeID
			, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	FROM CashTransaction ct
		JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
		JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	WHERE 
		b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
		AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
		AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
		AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
		AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
		and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))    
	GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID,b.bkBankTypeID;
	
	-- Get Adjust Bank Amount in machine
	INSERT INTO @CashActivity
	(
		gamingDate, 
		sessionNbr
		,staffIdNbr
		,staffLastName, staffFirstName,
		BanksIssuedTo,
		BankType
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
	)
	SELECT	ct.ctrGamingDate,
			ct.ctrGamingSession		
			, b.bkStaffID
			, 'Bank', 'Master',
			SUM(ISNULL(ctd.ctrdDefaultTotal*-1, 0)),
			b.bkBankTypeID
			, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	FROM CashTransaction ct
		JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
		JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
		
	WHERE 
		b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
		AND ct.ctrTransactionTypeID IN (29) -- Drops
		AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
		AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
		AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
	
		and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	GROUP BY ct.ctrGamingDate, ct.ctrGamingSession,b.bkStaffID,b.bkBankTypeID
		 
  
	-- Get banks issued from our staff member
	INSERT INTO @CashActivity
	(
		gamingDate, 
		sessionNbr,
		staffIdNbr,
		staffLastName, staffFirstName,
		BanksIssuedFrom,
		BankType
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
	)
	SELECT	ct.ctrGamingDate,
			ct.ctrGamingSession,
			b.bkStaffID, 'Bank', 'Master',
			SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)),
			b.bkBankTypeID
			, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	FROM CashTransaction ct
		JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
		JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	WHERE 
		b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
		AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
		AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
		AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
		AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
		and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))    
	GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID,b.bkBankTypeID;

	-- Get banks dropped to our staff member
	INSERT INTO @CashActivity
	(
		gamingDate, 
		sessionNbr,
		staffIdNbr,
		staffLastName, staffFirstName,
		DropsTo,
		BankType
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts, accrualPayouts, prizeFees
	)
	SELECT	ct.ctrGamingDate,
			ct.ctrGamingSession,
			b.bkStaffID, 'Bank', 'Master',
			SUM(ISNULL(ctd.ctrdDefaultTotal, 0)),
			b.bkBankTypeID
			, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	FROM CashTransaction ct
		JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
		JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	WHERE 
		b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
		AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank closes
		AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
		AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
		AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
		and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID,b.bkBankTypeID;


end					-- end Machine Mode
-- END DE8853


--
-- Paper sales: both register sales and inventory (floor sales)
-- 
insert @CashActivity
(
	productItemName
	, staffIdNbr, staffLastName, staffFirstName
	, price
	, gamingDate
	, sessionNbr
	, itemQty
	, merchandise
	, paper, paperSalesFloor, paperSalesTotal
	, electronic
	, credit
	, discount
	, other
	, bingoPayouts
	, pullTabPayouts
	, Taxes
	, Fees
    , BanksIssuedTo 
    , BanksIssuedFrom 
    , DropsTo 
    , TotalDrop 
	, pullTabSales
	, BankType
	, accrualPayouts 
	, prizeFees
	
)
select 
	 ItemName
	, fps.StaffID, s.LastName, s.FirstName
	, Price, GamingDate, SessionNo
	, Qty
	, 0
	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
	, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,2,0,0
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
	join Staff s on fps.StaffID = s.StaffID
where (@StaffID = 0 or s.StaffID = @StaffID)
	and s.LoginNumber > 0;				-- DE8482


-- Results table required to consolidate session 0 and 1	
declare @RESULTS table
(
	staffIdNbr          int,            
	staffName           NVARCHAR(130),
	gamingDate          datetime,       
	sessionNbr          int,            
	merchandise			MONEY,
	paper				MONEY,          -- original field, represents paper sales made at a register
	paperSalesFloor 	MONEY,          
	paperSalesTotal 	MONEY,          
	electronic			MONEY,
	credit				MONEY,
	discount			MONEY,
	coupon			MONEY,
	other				MONEY
	, bingoPayouts money
	, pullTabPayouts money
	, Taxes money
	, Fees  money
    , BanksIssuedTo MONEY
    , BanksIssuedFrom MONEY
    , DropsTo MONEY
    , TotalDrop MONEY
	, pullTabSales money
	, BankType int
	, accrualPayouts MONEY
	, prizeFees MONEY
	, DropsFrom money
);

-- Session not applicable: day long activity not attached to a session
with NA_SESSION
(
    sessionNbr, gamingDate,
    staffIdNbr, staffName,
    merchandise, paper, paperSalesFloor, paperSalesTotal, 
	electronic, credit, discount, coupon, other, bingoPayouts, pullTabPayouts,
	taxes, fees, BanksIssuedTo, BanksIssuedFrom, DropsTo, TotalDrop, pullTabSales, BankType, accrualPayouts, prizeFees
	, DropsFrom
)
as 
(
SELECT	
		ISNULL(sessionNbr, -1)
		, gamingDate
        , staffIdNbr, staffLastName + ', ' + staffFirstName
		, (isnull(merchandise, 0)) AS merchandise
		, (isnull(paper, 0)) AS paper
        , (isnull(paperSalesFloor, 0)) as paperSalesFloor
        , (isnull(paperSalesTotal, 0)) as paperSalesTotal        
		, (isnull(electronic, 0)) AS electronic
		, (isnull(credit, 0)) AS credit
		, (isnull(discount, 0)) AS discount
		, (isnull(coupon, 0)) AS coupon
		, (isnull(other, 0)) AS other
		, (-1 * (isnull(bingoPayouts, 0))) AS bingoPayouts
		, (isnull(pullTabPayouts, 0)) AS pullTabPayouts
		, (isnull(taxes, 0)) as taxes
		, (isnull(fees, 0)) as fees
		, (ISNULL(BanksIssuedTo, 0)) AS BanksIssuedTo
		, (ISNULL(BanksIssuedFrom, 0)) AS BanksIssuedFrom
		, (ISNULL(DropsTo, 0)) AS DropsTo
		, (ISNULL(TotalDrop, 0)) AS TotalDrop
		, (ISNULL(pullTabSales, 0)) AS pullTabSales
		, (ISNULL(BankType, 2)) as BankType	
		, (-1 * (ISNULL(accrualPayouts, 0))) as accrualPayouts
		, (ISNULL(prizeFees, 0)) as prizeFees
		, (isnull(DropsFrom, 0)) as DropsFrom
FROM @CashActivity
where sessionNbr < 0)
--GROUP BY gamingDate, positionId, positionName, staffIdNbr, staffLastName, staffFirstName
insert @RESULTS
(
	sessionNbr,
	gamingDate,
	staffIdNbr,
	staffName,
	merchandise,
	paper,
	paperSalesFloor,
	paperSalesTotal,
	electronic,
	credit,
	discount,
	coupon,
	other,
	bingoPayouts,
	pullTabPayouts,
	Taxes,
	Fees,
    BanksIssuedTo,
    BanksIssuedFrom,
    DropsTo,
    TotalDrop,
	pullTabSales,
	BankType,
	accrualPayouts,
	prizeFees,
	DropsFrom
)
select 
    -1 [Session]
  , gamingDate
  , staffIdNbr, staffName
  , sum(merchandise), sum(paper), sum(paperSalesFloor), sum(paperSalesTotal)
  , sum(electronic), sum(credit), sum(discount) ,sum(coupon) ,sum(other), sum(bingoPayouts), sum(pullTabPayouts)
  , sum(taxes), sum(fees), sum(BanksIssuedTo), sum(BanksIssuedFrom), sum(DropsTo), sum(TotalDrop), sum(pullTabSales),BankType, sum(accrualPayouts), sum(prizeFees)
  , sum(DropsFrom)
from NA_SESSION
group by gamingDate
	, staffIdNbr, staffName,BankType
ORDER BY gamingDate
	, staffIdNbr;

-- Session 0 and 1 combine bank activity 
with FIRSTSESSION
(
    sessionNbr, gamingDate,
    staffIdNbr, staffName,
    merchandise, paper, paperSalesFloor, paperSalesTotal, 
	electronic, credit, discount, coupon, other, bingoPayouts, pullTabPayouts,
	taxes, fees, BanksIssuedTo, BanksIssuedFrom, DropsTo, TotalDrop, pullTabSales,BankType, accrualPayouts, prizeFees
	, DropsFrom
)
as 
(
SELECT	
		ISNULL(sessionNbr, -1)
		, gamingDate
        , staffIdNbr
		--, staffLastName + ', ' + staffFirstName
		, staffFirstName + ' ' + staffLastName
		, (isnull(merchandise, 0)) AS merchandise
		, (isnull(paper, 0)) AS paper
        , (isnull(paperSalesFloor, 0)) as paperSalesFloor
        , (isnull(paperSalesTotal, 0)) as paperSalesTotal        
		, (isnull(electronic, 0)) AS electronic
		, (isnull(credit, 0)) AS credit
		, (isnull(discount, 0)) AS discount
		, (isnull(coupon, 0)) AS coupon
		, (isnull(other, 0)) AS other
		, (-1 * (isnull(bingoPayouts, 0))) AS bingoPayouts
		, (isnull(pullTabPayouts, 0)) AS pullTabPayouts
		, (isnull(taxes, 0)) as taxes
		, (isnull(fees, 0)) as fees
		, (ISNULL(BanksIssuedTo, 0)) AS BanksIssuedTo
		, (ISNULL(BanksIssuedFrom, 0)) AS BanksIssuedFrom
		, (ISNULL(DropsTo, 0)) AS DropsTo
		, (ISNULL(TotalDrop, 0)) AS TotalDrop
		, (ISNULL(pullTabSales, 0)) AS pullTabSales
		, (ISNULL(BankType, 2)) AS BankType	
		, (-1 * (ISNULL(accrualPayouts, 0))) AS accrualPayouts
		, (ISNULL(prizeFees, 0)) as prizeFees
		, (isnull(DropsFrom, 0)) as DropsFrom
FROM @CashActivity
where sessionNbr in (0, 1)
)
insert @RESULTS
(
	sessionNbr,
	gamingDate,
	staffIdNbr,
	staffName,
	merchandise,
	paper,
	paperSalesFloor,
	paperSalesTotal,
	electronic,
	credit,
	discount,
	coupon,
	other,
	bingoPayouts,
	pullTabPayouts,
	Taxes,
	Fees,
    BanksIssuedTo,
    BanksIssuedFrom,
    DropsTo,
    TotalDrop,
	pullTabSales,
	BankType,
	accrualPayouts,
	prizeFees
	, DropsFrom
)
select 
    1 [Session]
  , gamingDate
  , staffIdNbr, staffName
  , sum(merchandise), sum(paper), sum(paperSalesFloor), sum(paperSalesTotal)
  , sum(electronic), sum(credit), sum(discount),sum(coupon) , sum(other), sum(bingoPayouts), sum(pullTabPayouts)
  , sum(taxes), sum(fees), sum(BanksIssuedTo), sum(BanksIssuedFrom), sum(DropsTo), sum(TotalDrop), sum(pullTabSales),BankType, sum(accrualPayouts), sum(prizeFees)
  , sum(DropsFrom)
from FIRSTSESSION
group by gamingDate
	, staffIdNbr, staffName,BankType
ORDER BY gamingDate
	, staffIdNbr;


-- Now, each subsequent will have issues and drops 
with LATERSESSIONS
(
    sessionNbr, gamingDate
    , staffIdNbr, staffName 
    , merchandise, paper, paperSalesFloor, paperSalesTotal
	, electronic, credit, discount, coupon,  other, bingoPayouts, pullTabPayouts
	, taxes, fees, BanksIssuedTo, BanksIssuedFrom, DropsTo, TotalDrop, pullTabSales,BankType, accrualPayouts, prizeFees
	, DropsFrom
)
as 
(
SELECT	
	  sessionNbr, gamingDate 
    , staffIdNbr
    --, (stafflastName + ', ' + staffFirstName) [StaffName]
	, (staffFirstName + ' ' + staffLastName) [StaffName]
	, SUM(isnull(merchandise, 0)) AS merchandise
	, SUM(isnull(paper, 0)) AS paper
    , SUM(isnull(paperSalesFloor, 0)) as paperSalesFloor
    , SUM(isnull(paperSalesTotal, 0)) as paperSalesTotal      
	, SUM(isnull(electronic, 0)) AS electronic
	, SUM(isnull(credit, 0)) AS credit
	, SUM(isnull(discount, 0)) AS discount
	, SUM(isnull(coupon, 0)) AS coupon
	, SUM(isnull(other, 0)) AS other
	, (-1 * SUM(isnull(bingoPayouts, 0))) AS bingoPayouts
	, SUM(isnull(pullTabPayouts, 0)) AS pullTabPayouts
	, SUM(isnull(taxes, 0)) as taxes
	, SUM(isnull(fees, 0)) as fees
	, SUM(ISNULL(BanksIssuedTo, 0)) AS BanksIssuedTo
	, SUM(ISNULL(BanksIssuedFrom, 0)) AS BanksIssuedFrom
	, SUM(ISNULL(DropsTo, 0)) AS DropsTo
	, SUM(ISNULL(TotalDrop, 0)) AS TotalDrop
	, SUM(ISNULL(pullTabSales, 0)) AS pullTabSales	
	, ISNULL(BankType, 2) AS BankType
	, (-1 * SUM(ISNULL(accrualPayouts, 0))) AS accrualPayouts
	, SUM(ISNULL(prizeFees, 0)) AS prizeFees
	, sum(isnull(DropsFrom, 0)) as DropsFrom
FROM @CashActivity
where sessionNbr >= 2
GROUP BY gamingDate, sessionNbr
	, staffIdNbr, stafflastName, staffFirstName,BankType
)
insert @RESULTS
(
	sessionNbr,
	gamingDate,
	staffIdNbr,
	staffName,
	merchandise,
	paper,
	paperSalesFloor,
	paperSalesTotal,
	electronic,
	credit,
	discount,
	coupon,
	other,
	bingoPayouts,
	pullTabPayouts,
	Taxes,
	Fees,
    BanksIssuedTo,
    BanksIssuedFrom,
    DropsTo,
    TotalDrop,
	pullTabSales,
	BankType,
	accrualPayouts,
	prizeFees
	, DropsFrom
)
select 
    sessionNbr
    , gamingDate
    , staffIdNbr, staffName 
    , merchandise, paper, paperSalesFloor, paperSalesTotal
	, electronic, credit, discount, coupon, other, bingoPayouts, pullTabPayouts
	, taxes, fees, BanksIssuedTo, BanksIssuedFrom, DropsTo, TotalDrop, pullTabSales,BankType,accrualPayouts,prizeFees
	, DropsFrom
from LATERSESSIONS;


select * from @RESULTS
where 
    (@StaffID = 0 or staffIdNbr = @StaffID)
and (@Session = 0 or sessionNbr = @Session)			-- de8957
ORDER BY gamingDate, sessionNbr, 
	staffIdNbr;

SET NOCOUNT OFF;










GO


