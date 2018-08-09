USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasion]    Script Date: 04/06/2015 15:26:46 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasion]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasion]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasion]    Script Date: 04/06/2015 15:26:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

      
CREATE proc [dbo].[spRptOccasion]           
 @OperatorID AS INT,      
 @StartDate AS DATETIME,      
 @Session AS INT      
 as  
 -- ===================================
 -- Author: Karlo Camacho
 -- Date Created: 12/12/2012 
 -- 03/15/2013 knc - DE10882: The Occasion Report is missing the Pull Tab sales for the session. FIXED
 -- 08/12/2013 tmp - DE11073: Missing the Crystal Ball Bingo sales.
 -- 04/06/2015 tmp - DE12416: Missing the quantity and amount voided for Paper and Pull Tabs products.
 -- ===================================


-- >>>>>>>>>>>>>>>>>>>TEST<<<<<<<<<<<<<<<<<<<<<<<<
-- declare 
 
--  @OperatorID AS INT,      
-- @StartDate AS DATETIME,      
-- @Session AS INT   
-- ,@EndDate datetime   

  
--set @OperatorID = 1      
--set @StartDate = '2013-03-15 00:00:00'      
--set @EndDate = @StartDate       
--set @Session = 0      
-->>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<
      
-- COMMENT
-- ==========================================    
-- This procedure is based on DoorSalesReport.
-- ==========================================      
declare @EndDate datetime                 
set @EndDate = @StartDate       

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
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)  -- Electronic
--			OR (rdi.CardMediaID = 2 and rdi.GameTypeID = 4)) 
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
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
--			OR (rdi.CardMediaID = 2 and rdi.GameTypeID = 4))
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
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
--			OR (rdi.CardMediaID = 2 AND rdi.GameTypeID = 4))
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
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
--			OR (rdi.CardMediaID = 2 AND rdi.GameTypeID = 4)) 
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



------------------------------------------------------------------------------------------------
-- Start DE12416: 
-- Old Code ------------------------------------------------------------------------------------
-- Paper sales: both register sales and inventory (floor sales)
------------------------------------------------------------------------------------------------ 
--insert @DoorSales
--(
--	groupName, productItemName,
--	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
--	itemQty,
--	merchandise,
--	paper, paperSalesFloor, paperSalesTotal,
--	electronic,
--	credit,
--	discount,
--	other,
--	payouts
--	, ProductTypeId     
--)
--select 
--	GroupName, ItemName, fps.StaffID, Price, GamingDate, SessionNo
--	, s.LastName + ', ' + s.FirstName -- staffname
--	, Qty
--	, 0
--	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
--	, 0, 0, 0, 0, 0
--	, ProdTypeID
--from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
--join Staff s on fps.StaffID = s.StaffID
--where fps.ProdTypeID > 4; -- DE8221 Do not account for CBB Sales they have been accounted for in the electronics


--------------------------------------------------------------------------------------------------
-- New Code --------------------------------------------------------------------------------------

------------------------------------------------------------------------
--Insert Product Type = Paper, Sales Source = Register
------------------------------------------------------------------------
-- Sales rows 
Insert into @DoorSales
(
	groupName,
	productItemName,
	price, 
	gamingDate, 
	sessionNbr, 
	itemQty,
	merchandise,
	paper, 
	paperSalesFloor, 
	paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts,
	ProductTypeId     
)
	SELECT	
			isnull(groupName, 'Paper'),
			rdi.ProductItemName,
			rdi.Price,
			rr.GamingDate,
			sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty),
			0,
			0,
			0,
			SUM(rd.Quantity * rdi.Qty * rdi.Price),
			0,
			0,
			0,
			0,
			0,
			rdi.ProductTypeID 
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1,2,3,4,16)
		And (@Session = 0 or sp.GamingSession = @Session)
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;
	
---Insert Voided Sales rows
Insert into @DoorSales
(
	groupName,
	productItemName,
	price, 
	gamingDate, 
	sessionNbr, 
	itemQtyVoid,
	merchandise,
	paperVoid, 
	paperSalesFloor, 
	paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts,
	ProductTypeId     
)
SELECT	
			isnull(groupName, 'Paper'),
			rdi.ProductItemName,
			rdi.Price,
			rr.GamingDate,
			sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty),            -- [QtyVoided]
			0,
			SUM(rd.Quantity * rdi.Qty * rdi.Price), --[VoidedSales]
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			rdi.ProductTypeID
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1,2,3,4,16)
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NOT NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

--Insert Return rows, returns go into QtySold and TotalSales
Insert into @DoorSales
(
	groupName,
	productItemName,
	price, 
	gamingDate, 
	sessionNbr, 
	itemQty,
	merchandise,
	paper, 
	paperSalesFloor, 
	paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts,
	ProductTypeId     
)
SELECT	
			isnull(groupName, 'Paper'),
			rdi.ProductItemName,
			rdi.Price,
			rr.GamingDate,
			sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty), -- [QtySold]
			0,
			0,
			0,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),  --  [TotalSales]
			0,
			0,
			0,
			0,
			0,
			rdi.ProductTypeID
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3							-- Returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1,2,3,4,16)
		And (@Session = 0 or sp.GamingSession = @Session)
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

----------------------------------------------------------------------
--Insert Product Type = Paper, Sales Source = Inventory
----------------------------------------------------------------------
Declare @PaperFloorSales table
(
		GamingDate      datetime,
		SessionNo       int,
		ProdTypeID      int,
		GroupName       nvarchar(64),
		PackageName     nvarchar(64),
		ItemName        nvarchar(64),
		Price           money,
		ReturnCount     int,            -- order determined by tran type
		SkipCount       int,
		BonanzaCount    int,            -- reserved for future
		IssueCount      int,
		PlaybackCount   int,            -- reserved for future
		DamageCount     int,
		TransferCount   int
)
Insert into @PaperFloorSales
select 
			ivtGamingDate
		, ivtGamingSession
		, pi.ProductTypeID
		, pg.GroupName
		, 'Floor Sales' [PackageName]  -- req'd b/c no direct link between inventory transaction and packages
		, pi.ItemName
		, ivtPrice
		, CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END     [ReturnsCount]
		, CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END    [SkipCount]
		, CASE ivtTransactionTypeID WHEN 24 THEN ivdDelta ELSE 0 END    [BonanzaCount]
		, CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END    [IssuedCount]
		, CASE ivtTransactionTypeID WHEN 26 THEN ivdDelta ELSE 0 END    [PlayBackCount]
		, CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END    [DamagedCount]
    	, CASE ivtTransactionTypeID WHEN 32 THEN ivdDelta ELSE 0 END    [TransferCount]
	from InventoryItem 
	join InvTransaction on iiInventoryItemID = ivtInventoryItemID
	join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID
	join InvLocations on ivdInvLocationID = ilInvLocationID
	left join IssueNames on ivtIssueNameID = inIssueNameID
	left join ProductItem pi on pi.ProductItemID = iiProductItemID
	left join ProductGroup pg on pi.ProductGroupID = pg.ProductGroupID
	where 
	(pi.OperatorID = @OperatorID)
	and (ivtGamingDate between @StartDate and @EndDate)
	and (ivtGamingSession = @Session or @Session = 0)
	and (ilMachineID <> 0 or ilStaffID <> 0)
	and pi.ProductTypeID = 16
	and pi.SalesSourceID = 1    -- Inventory source sale
	
Insert into @DoorSales
(
	groupName,
	productItemName,
	price, 
	gamingDate, 
	sessionNbr, 
	itemQty,
	merchandise,
	paper, 
	paperSalesFloor, 
	paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts,
	ProductTypeId    
) 
Select 
		GroupName, 
		ItemName,
		Price,
		GamingDate, 
		SessionNo,
		SUM(IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount), --  [QtySold]
		0,
		0,
		0,
		SUM(Price * (IssueCount + ReturnCount + DamageCount + SkipCount +TransferCount)) [TotalSales],    -- ADD since these qtys are negative
		0,
		0,
		0,
		0,
		0,
		ProdTypeID
From @PaperFloorSales
Group By GamingDate, SessionNo, GroupName, ItemName, Price, PackageName, ProdTypeID;

--- End DE12416

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
	into #b
	from @DoorSales
	group by groupName, ProductTypeId,ProductType,productItemName, price, gamingDate, sessionNbr, staffIdNbr, staffName
	order by groupName, ProductTypeId,productItemName, price, gamingDate, sessionNbr, staffIdNbr;
   
           
select * from #b        
where ProductTypeId in (1, 2, 3, 4, 5, 14, 16, 17) 
      
--and [Session] = @Session
and ([Session] = @Session or @Session = 0) 
      
--select count(GamingDate), GamingDate from #b group by GamingDate order by count(GamingDate) desc      
      
      
drop table #b       
       
--end;      
-- END US1902      
      
      
--IF OBJECT_ID('tempdb..#a') IS NOT NULL      
--BEGIN      
--select * into #c from #a       
--PRINT '#a exists!'      
--drop table #a       
--END      
--ELSE      
--IF OBJECT_ID('tempdb..#b') IS NOT NULL      
--BEGIN      
--select * into #c from #b       
--PRINT '#b does not exist!'      
--drop table #b       
--END      
      
--select * from #c        
      
--drop table #c       
      
--SELECT * FROM INFORMATION_SCHEMA.TABLES where TABLE_NAME like '#b'            
      
SET NOCOUNT OFF      
      

GO

