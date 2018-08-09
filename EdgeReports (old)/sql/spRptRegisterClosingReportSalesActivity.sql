USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportSalesActivity]    Script Date: 01/24/2012 15:55:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportSalesActivity]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportSalesActivity]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportSalesActivity]    Script Date: 01/24/2012 15:55:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO









CREATE PROCEDURE  [dbo].[spRptRegisterClosingReportSalesActivity] 
-- =============================================
-- 2012.1.24  SA : DE9937: missing machineId for papersales 
-- =============================================
  
@OperatorID		AS INT,
@StartDate		AS DATETIME,
@EndDate		AS DATETIME,
@StaffID		AS INT,
@Session		AS INT,
@MachineID      as int

AS
	
-- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);

-- FIX EDGE 3.4 PATCH
-- When in Machine Mode (2) display all staff members when printing
declare @CashMethod int;
select @CashMethod = CashMethodID from Operator
where OperatorID = @OperatorID;

-- END EDGE 3.4 PATCH


-- Results table	
declare @SalesActivity table
(
    --packageName         NVARCHAR(64),	-- 2011.07.21: beta fix
	productItemName		NVARCHAR(64),
	staffIdNbr          int,            -- DE7731
	staffName           NVARCHAR(64),
	soldFromMachineId   int,
	itemQty			    INT,            -- TC822
	issueQty			INT,
	returnQty			INT,
	skipQty				INT,
	damageQty			INT,		
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
	payouts				MONEY					
);


	
--		
-- Insert Merchandise Rows		
--
INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
	soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,    
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
        rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731
        rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00,
		0.00
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
	and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)	-- DE8882
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

-- And take out returns
INSERT INTO @SalesActivity
(
    
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,    
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
	0.00, 0.00, 0.00,
	0.00,
	0.00,
	0.00,
	0.00,
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731



--		
-- Insert Electronic Rows		
--
INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
	soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName,
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
	rr.SoldFromMachineID,
	SUM(rd.Quantity * rdi.Qty),--itemQty,
	0.0,--merchandise,
	0.0, 0.0, 0.0, --paper,
	SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,
	0.0,--credit,
	0.0,--discount,
	0.0,--other,
	0.0--payouts		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	--JOIN #TempDevicePerReceipt dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	--LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID; 

INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName,
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
	rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
	0.0,--merchandise,
	0.0,0.0,0.0, --paper,
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
	0.0,--credit,
	0.0,--discount,
	0.0,--other,
	0.0--payouts		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	--JOIN #TempDevicePerReceipt dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	--LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID; 


--		
-- Insert Credit Rows		
--
INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	SUM(rd.Quantity * rdi.Qty * rdi.Price),
	0.00,
	0.00,
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
	rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0,
	0.00,
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
	0.00,
	0.00,
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

--		
-- Insert Discount Rows		
--
-- DE7731: treat discounts like sales
INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	0.00,
	SUM(rd.Quantity * rdi.Qty * rdi.Price),
	0.00,
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	0.00,
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
	0.00,
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

-- FIX DE8480,8481: Restore original discounts as well as new product-name discounts
--		
-- Insert Discount Rows		
--
INSERT INTO @SalesActivity
	(
		 productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
	)
SELECT	
        dt.DiscountTypeName, 
    	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),
		0.00,
		0.00
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
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;

INSERT INTO @SalesActivity
	(
		 productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffName,
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		payouts
	)
SELECT	
        dt.DiscountTypeName, 
    	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		rr.SoldFromMachineId,
		SUM(-1 * rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1??????????????
		0.00,
		0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;
-- END FIX DE8480,8481



--		
-- Insert Other Rows		
--
INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	0.00,
	0.00,
	SUM(rd.Quantity * rdi.Qty * rdi.Price),
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

INSERT INTO @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId, 
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts
)
SELECT	
    rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	0.00,
	0.00,
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
	0.00
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;         -- DE7731

--		
-- Insert Payout Rows		
--
-- TODO: Not currently doing "Payouts"


-------------------------------------------------------------------------------------------
-- PAPER SALES
--
-- Paper sales: both register sales and inventory (floor sales)
-- 
insert @SalesActivity
(
	productItemName
    , staffIdNbr, staffName
    , soldFromMachineId
	, price, gamingDate, sessionNbr
	, itemQty
	, merchandise
	, paper, paperSalesFloor, paperSalesTotal
	, electronic, credit, discount, other, payouts
)
select 
	ItemName
	, fps.StaffID, s.LastName + ', ' + s.FirstName
	, fps.soldFromMachineId
	, Price, GamingDate, SessionNo
	, Qty
	, 0
	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
	, 0, 0, 0, 0, 0
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
join Staff s on fps.StaffID = s.StaffID
where 
    (@StaffID = 0 or s.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
     and (@MachineID = 0 or fps.soldFromMachineId = @MachineID )
        

-- PRODUCTION			
select 
    staffIdNbr,staffName, gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
	, productItemName
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
    --, sum(price) as Price  ONLY SHOW SINGLE PRICE  0524
    , price
    , SUM(itemQty) AS QTY      
    , (SUM(merchandise) +
		SUM(paper) +
        SUM(paperSalesFloor) +
        SUM(electronic)+
		SUM(credit) +
		SUM(discount) +
		SUM(other) +
		SUM(payouts)) as Value
FROM @SalesActivity
group by staffIdNbr,staffName,GamingDate,sessionNbr, productItemName, soldFromMachineId, price
order by staffIdNbr,gamingDate, sessionNbr ;

-- cleanup
--drop table @IssueData;
    
SET NOCOUNT OFF;






GO


