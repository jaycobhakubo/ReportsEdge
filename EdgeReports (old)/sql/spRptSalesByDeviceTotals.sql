USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceTotals]    Script Date: 06/28/2011 12:47:43 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByDeviceTotals]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByDeviceTotals]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceTotals]    Script Date: 06/28/2011 12:47:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[spRptSalesByDeviceTotals]
(
-- =============================================
-- Author:		<Louis J. Landerman>
-- Description:	<>
-- 03/08/2011 BJS: DE7731 add floor sales
-- 03/11/2011 BJS: DE7729,7727 add ability to display buyins
--                 and reuse this sp for all 3 reports (by item, by package too).
-- 03/22/2011 BJS: TC765 fixes for DE7731
-- 05/18/2011 BJS: DE8073 restore original discounts
-- 06/20/2011 bjs: DE8654 missing floor workers
-- 06/28/2011 bjs: DE7729 cloned spRptSalesByPackage to consolidate biz logic
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@Session	AS	INT
)
AS

begin
	SET NOCOUNT ON;

	-- Cloned from spRptSalesByPackage.  Added device specific code from previous version on LATIN.
	-- Results table: use table var for performance
	declare @Sales table
	(
	    deviceName			NVARCHAR(64),
		productItemName		NVARCHAR(64),
		staffIdNbr          int,            -- DE7731
		staffName           NVARCHAR(64),
		itemQty			    INT,            -- TC822
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
		, ProductTypeId     int             -- bjs 5/25/11 Crystal Ball Bingo paper products are non-inventory paper!
	);

    --
    -- Populate Device Lookup Table
    --
    declare @TempDevicePerReceipt table
    (
	    registerReceiptID	INT,
	    deviceID			INT
    );
    	
    INSERT @TempDevicePerReceipt
    (
	    registerReceiptID,
	    deviceID
    )
    SELECT	rr.RegisterReceiptID,
		    (SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)		
    FROM RegisterReceipt rr
    Where rr.GamingDate between @StartDate and @EndDate;

-- debug
--select * from @TempDevicePerReceipt;
--return;		
		
	--		
	-- Insert Merchandise Rows		
	--
	INSERT INTO @Sales
		(
		    deviceName,
			productItemName,
			staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
			itemQty,
			merchandise,
			paper, paperSalesFloor, paperSalesTotal,    
			electronic,
			credit,
			discount,
			other,
			payouts,
			ProductTypeId     
		)
	SELECT	'Merchandise',
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
		and rd.VoidedRegisterReceiptID IS NULL
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;         -- DE7731

	-- And take out returns
	INSERT INTO @Sales
		(   
		    deviceName,
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
	SELECT	'Merchandise',
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
		and rd.VoidedRegisterReceiptID IS NULL
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID; 

	-- DEBUG
	--select * from @Sales;
	--return;


	--		
	-- Insert Electronic Rows		
	--
	INSERT INTO @Sales
		(   
		    deviceName,
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
	        ISNULL(d.DeviceType, 'Pack'),
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
	    JOIN @TempDevicePerReceipt dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	    LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
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
	GROUP BY d.DeviceType, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	INSERT INTO @Sales
		(
			deviceName,
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
	        ISNULL(d.DeviceType, 'Pack'),
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
	    JOIN @TempDevicePerReceipt dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	    LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
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
	GROUP BY d.DeviceType, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	--		
	-- Insert Credit Rows		
	--
	INSERT INTO @Sales
		(
		    deviceName,
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
	        'Credits',
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	INSERT INTO @Sales
		(
		    deviceName,
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
	        'Credits',
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID; 

	--		
	-- Insert Discount Rows		
	--
	-- DE7731: treat discounts like sales
	INSERT INTO @Sales
		(
		    deviceName,
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
	        'Discounts',
	        rdi.ProductItemName, 
			rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
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
		AND (rdi.ProductTypeID = 14 AND RDI.ProductItemName LIKE 'Discount%' )
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	INSERT INTO @Sales
		(
		    deviceName,
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
	        'Discounts',
	        rdi.ProductItemName, 
			rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
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
		AND (rdi.ProductTypeID = 14 AND RDI.ProductItemName LIKE 'Discount%' )
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	-- FIX DE8075: Restore original discounts as well as new product-name discounts
	--		
	-- Insert Discount Rows		
	--
	INSERT INTO @Sales
		(
		    deviceName,
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	INSERT INTO @Sales
		(
		    deviceName,
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;
	-- END FIX DE8075

	--		
	-- Insert Other Rows		
	--
	INSERT INTO @Sales
		(
		    deviceName,
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
	SELECT	'Other Sales',
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;

	INSERT INTO @Sales
		(
		    deviceName,
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
	SELECT	'Other Sales',
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
		and rd.VoidedRegisterReceiptID IS NULL
	GROUP BY rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;


	--
	-- Paper sales: both register sales and inventory (floor sales)
	-- 
	insert @Sales
	(
	    deviceName,
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
	select 
	    'Paper'
		, ItemName, fps.StaffID, Price, GamingDate, SessionNo
		, s.LastName + ', ' + s.FirstName -- staffname
		, Qty
		, 0
		, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
		, 0, 0, 0, 0, 0
		, ProdTypeID
	
	from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
	join Staff s on fps.StaffID = s.StaffID;

	-- Return our resultset!
	select * from @Sales
	order by deviceName, productItemName, gamingDate, sessionNbr, staffIdNbr;

end;

SET NOCOUNT OFF;
GO


