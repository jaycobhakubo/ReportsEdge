USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales]    Script Date: 01/25/2012 10:20:13 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales]    Script Date: 01/25/2012 10:20:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptDoorSales] 
-- =============================================
-- Author:		Louis J. Landerman
-- Description:	<>
--
-- LJL - 02/03/2011 - Added Discounts to report
-- BJS - 03/07/2011  DE7730: add floor workers
-- BJS 06/21/2011    DE8654 missing floor workers
-- 06/28/2011 bjs: combined all paper sales logic into a udf.
-- 2011.07.05 bjs: DE8801 void amounts separated from sales
-- 2011.07.07 jkn: DE8221 missing voided CBB paper sales
-- 2011.07.15 bjs: DE8879 missing discount price
-- 2011.08.05 bjs: US1902 add prod group para
-- bsb -01/26/12 : DE9910
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int
AS
	
SET NOCOUNT ON
-----------------------------------------------------------------------------------------------------------------------------------
-- cloned from spRptSalesByPackageTotals
-- Door Sales requires VOIDS

-- Results table	
declare @DoorSales table
	(
        groupName         NVARCHAR(64),
		productItemName		NVARCHAR(64),
		staffIdNbr          int,            -- DE7731
		staffName           NVARCHAR(64),
		itemQty			    INT,            -- TC822
		issueQty			INT,
		returnQty			INT,
		skipQty				INT,
		damageQty			INT,		

		itemQtyVoid		    INT,            -- DE7721: add voided quantities so logic for inv/registers sales is shared across multiple sp's
		issueQtyVoid		INT,
		returnQtyVoid		INT,
		skipQtyVoid			INT,
		damageQtyVoid		INT,		

		pricePaid           money,
		price               money,          -- DE7731
		gamingDate          datetime,       -- DE7731
		sessionNbr          int,            -- DE7731
		
		merchandise			MONEY,
		paper				MONEY,          -- original field, represents paper sales made at a register
		paperSalesFloor 	MONEY,          -- DE7731
		paperSalesTotal 	MONEY,          -- DE7731
		electronic			MONEY,
		credit				MONEY,
		discount			MONEY,
		other				MONEY,
		payouts				MONEY,	
		
		merchandiseVoid		MONEY,			-- DE7721: track voids
		paperVoid			MONEY,          
		paperSalesFloorVoid MONEY,          
		paperSalesTotalVoid MONEY,          
		electronicVoid		MONEY,
		creditVoid			MONEY,
		discountVoid		MONEY,
		otherVoid			MONEY,
		payoutsVoid			MONEY	
						
        , ProductTypeId     int             -- bjs 5/25/11 Crystal Ball Bingo paper products are non-inventory paper!
        ,ProductType    varchar(100)
	);

		
--		
-- Insert Merchandise Rows		
--
INSERT INTO @DoorSales
	(
		groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,    
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName, 
		--NULL,
		--'',
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;         -- DE7731

-- And take out returns
INSERT INTO @DoorSales
	(
	    groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


------------------------------------------
-- DE7721: add voids
--		
-- Insert Merchandise VOIDS	
--
INSERT INTO @DoorSales
	(
		groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
		itemQtyVoid,
		merchandiseVoid,
		paper, paperSalesFloor, paperSalesTotal,    
		electronicVoid,
		creditVoid,
		discountVoid,
		otherVoid,
		payoutsVoid
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;         -- DE7731

-- And take out VOIDED returns
INSERT INTO @DoorSales
	(
		groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
		itemQtyVoid,
		merchandiseVoid,
		paper, paperSalesFloor, paperSalesTotal,    
		electronicVoid,
		creditVoid,
		discountVoid,
		otherVoid,
		payoutsVoid
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


--		
-- Insert Electronic Rows		
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0, 0.0, 0.0, --paper,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0,--other,
		0.0--payouts
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL  -- Electronic
			OR (rdi.CardMediaID = 2 and rdi.GameTypeID = 4)) -- DE8221 Account for Paper CBB
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

-- RETURNS
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		--deviceID,
		--deviceName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0,0.0,0.0, --paper,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0,--other,
		0.0--payouts
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL -- Electronic
			OR (rdi.CardMediaID = 2 and rdi.GameTypeID = 4)) -- DE8221 Account for Paper CBB
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 



--		
-- Insert Electronic VOIDS	
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		electronicVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS not NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL -- Electronic
			OR (rdi.CardMediaID = 2 AND rdi.GameTypeID = 4)) -- DE8221 Account for Paper CBB
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

-- Electronic void returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		electronicVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS not NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL -- Electronic
			OR (rdi.CardMediaID = 2 AND rdi.GameTypeID = 4)) -- DE8221 Account for Paper CBB
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 


--		
-- Insert Credit Rows		
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Credit returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00,
		0.00
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731



--		
-- Insert Credit VOIDS
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		creditVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Credit void returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		creditVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID
		, rd.DiscountAmount  -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
	    rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rd.DiscountAmount, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


--		
-- Insert Discount Rows		
--
-- DE7731: treat discounts like sales
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID
		, (isnull(rd.DiscountAmount, ISNULL(rdi.price, 0))) [Price]		-- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, rdi.ProductTypeID
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
	AND (rdi.ProductTypeID = 14	and RDI.ProductItemName LIKE 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rd.DiscountAmount, rdi.Price,  rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Discount returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID
		, (isnull(rd.DiscountAmount, ISNULL(rdi.price, 0))) [Price] -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, rdi.ProductTypeID
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rd.DiscountAmount, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

--		
-- Insert Discount VOIDS		
--
-- DE7731: treat discounts like sales
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		discountVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID
		, (isnull(rd.DiscountAmount, ISNULL(rdi.price, 0))) [Price] -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	AND (rdi.ProductTypeID = 14	and RDI.ProductItemName LIKE 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rd.DiscountAmount, rdi.Price,  rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Discount void returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		discountVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID
		, (isnull(rd.DiscountAmount, ISNULL(rdi.price, 0))) [Price] -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rd.DiscountAmount, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


-- FIX DE8075: Restore original discounts as well as new product-name discounts
--		
-- Insert Discount Rows		
--
INSERT INTO @DoorSales
	(
		groupName, 
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	'Discounts',
        dt.DiscountTypeName, 
		rr.StaffID
		, rd.DiscountAmount  -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),
		0.00,
		0.00
		, 14  -- this is an original discount so make the type identical to the new discounts
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY dt.DiscountTypeName, rr.StaffID, rd.DiscountAmount, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;

-- Discount returns
INSERT INTO @DoorSales
	(
	    groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	'Discounts',
        dt.DiscountTypeName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		SUM(-1 * rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1?
		0.00,
		0.00
		, 14  -- this is an original discount so make the type identical to the new discounts
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
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 
-- END FIX DE8075

--		
-- Insert original style Discount VOIDS
--
INSERT INTO @DoorSales
	(
		groupName, 
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		discountVoid,
        ProductTypeId     
	)
SELECT	'Discounts',
        dt.DiscountTypeName, 
		rr.StaffID
		, rd.DiscountAmount  -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		SUM(rd.Quantity),
		SUM(rd.Quantity * rd.DiscountAmount),
		14  -- this is an original discount so make the type identical to the new discounts
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL  
GROUP BY dt.DiscountTypeName, rr.StaffID, rd.DiscountAmount, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;

-- Discount void returns
INSERT INTO @DoorSales
	(
	    groupName,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		discountVoid,
        ProductTypeId     
	)
SELECT	'Discounts',
        dt.DiscountTypeName, 
		rr.StaffID
		, rd.DiscountAmount  -- DE8879
		, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		SUM(-1 * rd.Quantity),
		SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1?
		14  -- this is an original discount so make the type identical to the new discounts
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
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY dt.DiscountTypeName, rr.StaffID, rd.DiscountAmount, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 


--		
-- Insert Other Rows		
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, rdi.ProductTypeID
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
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Other returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
        , ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, rdi.ProductTypeID
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
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	-- and rd.VoidedRegisterReceiptID IS NULL  -- DE8801
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731



--		
-- Insert Other VOIDS		
--
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		otherVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

-- Other void returns
INSERT INTO @DoorSales
	(
		groupName,productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		itemQtyVoid,
		otherVoid,
        ProductTypeId     
	)
SELECT	
        isnull(rdi.GroupName, 'Non Grouped Items'),
        rdi.ProductItemName,
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		rdi.ProductTypeID
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
	AND (rdi.ProductTypeID IN (6, 8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL
GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


--
-- Paper sales: both register sales and inventory (floor sales)
-- 
insert @DoorSales
(
	groupName, productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
	, ProductTypeId     
)
select 
	GroupName, ItemName, fps.StaffID, Price, GamingDate, SessionNo
	, s.LastName + ', ' + s.FirstName -- staffname
	, Qty
	, 0
	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
	, 0, 0, 0, 0, 0
	, ProdTypeID
	
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
join Staff s on fps.StaffID = s.StaffID
where fps.ProdTypeID <> 4; -- DE8221 Do not account for CBB Sales they have been accounted for in the electronics
        
update 	t1
	set	t1.ProductType = t2.producttype
from	@DoorSales t1 inner join
	(
		select ProductTypeID, 	ProductType 
		from	ProductType
		
	) as t2
	on	t1.ProductTypeId	= t2.ProductTypeID;
-- FIX US1902
-- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...
if(@ProductGroupID <> 0)
begin
	declare @groupName nvarchar(64); --set @groupName = 'All Groups';
	select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;

	-- return our resultset using same field names as rpt file expects!
	select 
	  isnull(ds.groupName, 'Non Grouped Items')			[ProductGroup]
	, productItemName	[ProductName]
	, isnull(price, 0)	[ProductPrice]
	, gamingDate		[GamingDate]
	, sessionNbr		[Session]
	, staffIdNbr		[StaffID]
	, staffName			[StaffName]
	, sum( isnull(itemQty, 0) )		[ProductQuantity]
	, sum( isnull(merchandise, 0) + isnull(paperSalesTotal, 0) + isnull(electronic, 0) + isnull(credit, 0) + isnull(discount, 0) + isnull(other, 0) ) [ProductTotal]
	, sum( isnull(itemQtyVoid, 0) )	[ProductVoidedQuantity]
	, sum( isnull(merchandiseVoid, 0) + isnull(paperVoid, 0) + isnull(electronicVoid, 0) + isnull(creditVoid, 0) + isnull(discountVoid, 0) + isnull(otherVoid, 0) ) [ProductVoidedTotal]
	,ProductTypeId
	, ProductType
	from @DoorSales ds
	where (ds.groupName = @groupName)
	group by ds.groupName,ProductTypeId,ProductType, productItemName, price, gamingDate, sessionNbr, staffIdNbr, staffName
	order by ds.groupName,ProductTypeId, productItemName, price, gamingDate, sessionNbr, staffIdNbr;


end
else
begin
	-- return our resultset using same field names as rpt file expects!
	select 
	  isnull(groupName, '')			[ProductGroup]
	, productItemName	[ProductName]
	, isnull(price, 0)	[ProductPrice]
	, gamingDate		[GamingDate]
	, sessionNbr		[Session]
	, staffIdNbr		[StaffID]
	, staffName			[StaffName]
	, sum( isnull(itemQty, 0) )		[ProductQuantity]
	, sum( isnull(merchandise, 0) + isnull(paperSalesTotal, 0) + isnull(electronic, 0) + isnull(credit, 0) + isnull(discount, 0) + isnull(other, 0) ) [ProductTotal]
	, sum( isnull(itemQtyVoid, 0) )	[ProductVoidedQuantity]
	, sum( isnull(merchandiseVoid, 0) + isnull(paperVoid, 0) + isnull(electronicVoid, 0) + isnull(creditVoid, 0) + isnull(discountVoid, 0) + isnull(otherVoid, 0) ) [ProductVoidedTotal]
	, ProductTypeId 
	, ProductType
	from @DoorSales
	group by groupName, ProductTypeId,ProductType,productItemName, price, gamingDate, sessionNbr, staffIdNbr, staffName
	order by groupName, ProductTypeId,productItemName, price, gamingDate, sessionNbr, staffIdNbr;
end;
-- END US1902



SET NOCOUNT OFF



GO


