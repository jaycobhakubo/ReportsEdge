USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPOSRegisterReport]    Script Date: 03/05/2014 16:22:41 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPOSRegisterReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPOSRegisterReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPOSRegisterReport]    Script Date: 03/05/2014 16:22:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO










CREATE PROCEDURE  [dbo].[spRptPOSRegisterReport] 
-- =============================================
-- Author:		<Louis J. Landerman>
-- Description:	<>
-- 2/24/2011 BJS: DE7636 add price for each line item.
-- 2011.07.06 bjs: DE8864 restrict to sold from machine
-- 2011.07.18 bjs: Mohawk field beta fix
-- 2011.08.08 bjs: DE8943 show price when in machine mode
-- 2012.05.23 bsb: US1808
-- 2012.06.12 bdh: DE10484 Don't include voided device fees.
-- 2013.03.05 knc: DE10772/TA11603 Add the device fees to the report.
-- 2014.03.05 tmp: US3097 Add support for the TedE
-- =============================================
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@StaffID	AS INT,
	@OperatorID	AS INT,
	@Session	AS INT,
	@MachineID	AS INT,
	@ByPackage AS int

AS

-- Setup our output table set
DECLARE @OutputTable TABLE(
	GamingSession INT,
	PackageName NVARCHAR(64),
	PackageQuantity INT,
	PackagePrice money,
	PackageTotal MONEY,
	StaffID INT,
	SoldFromMachine INT,
	DiscountAmount MONEY,
	CouponAmount MONEY,
	ReturnAmount MONEY,
	VoidAmount MONEY,
	FixedUnitSales MONEY,
	TravelerSales MONEY,
	Traveler2Sales MONEY,
	TrackerSales MONEY,
	ExplorerSales MONEY,
	TedeSales MONEY, --US2971
	PackSales MONEY,
	SalesTax MONEY,
	DeviceFee MONEY,
	BankAmount MONEY,
	Price MONEY
);

--
-- Populate Device Lookup Table to matchup a device with a register receipt using
-- the UnLockLog for lookups.
--
DECLARE @TempDevicePerReceiptDeviceSummary TABLE
	(
		registerReceiptID	INT,
		deviceID			INT,
		soldToMachineID		INT,
		unitNumber			INT
	);
INSERT INTO @TempDevicePerReceiptDeviceSummary
	(
		registerReceiptID,
		deviceID,
		soldToMachineID,
		unitNumber
	)
SELECT	rr.RegisterReceiptID,
		(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 ulUnitNumber FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)
FROM RegisterReceipt rr
Where	(rr.GamingDate between @StartDate and @EndDate)
    	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID); -- DE8864
	
-- Get the cash method we will be using to determine
-- which records to show on this report
DECLARE @CashMethod INT
SELECT @Cashmethod = CashMethodID
FROM Operator
WHERE OperatorID = @OperatorID;

-- debug
print 'Cash Method: ' + convert(nvarchar(5), @CashMethod);

-- Handle "Track By Staff"
IF @CashMethod IN (1,3)
BEGIN
    
    	--Add coupon	
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		CouponAmount,
		SalesTax
	)
	
	select 
	GamingSession,
	NULL,
	sum(QuantitySold),
	0,
	StaffID,
	max(SoldFromMachineID), 
	SUM (NetSales),
	0
	 from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)
	group by GamingSession,StaffID
    
	-- Add Package Sales
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		SalesTax
		, Price	-- DE7636
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			rd.PackageName,
			SUM(rd.Quantity),
			max(rd.PackagePrice),
			SUM(rd.PackagePrice * rd.Quantity),
			rr.StaffID,
			MAX(rr.SoldFromMachineID),
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
			, rd.PackagePrice -- DE7636	
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	AND PackageName IS NOT NULL
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession, rd.PackageName, rr.StaffID
			, rd.PackagePrice -- DE7636	
	ORDER BY PackageName;

	-- Add Package Discounts
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		SalesTax
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			NULL,
			SUM(rd.Quantity),
			MAX(rd.PackagePrice),
			0,
			rr.StaffID,
			MAX(rr.SoldFromMachineID),
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN DiscountTypes dt ON (rd.DiscountTypeID = dt.DiscountTypeID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	AND PackageName IS NULL
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession, dt.DiscountTypeName, rr.StaffID
	ORDER BY DiscountTypeName;



	-- Add Package Returns
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		ReturnAmount,
		SalesTax
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			rd.PackageName,
			SUM(-1 * rd.Quantity),
			MAX(rd.packagePrice),
			SUM(rd.PackagePrice * rd.Quantity),
			rr.StaffID,
			MAX(rr.SoldFromMachineID),
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(rd.PackagePrice * rd.Quantity),
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 3
	AND rr.SaleSuccess = 1
	AND PackageName IS NOT NULL
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession, rd.PackageName, rr.StaffID
	ORDER BY PackageName;

	-- Add Discount Returns
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		ReturnAmount,
		SalesTax
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			NULL,
			SUM(-1 * rd.Quantity),
			MAX(rd.PackagePrice),
			0,
			rr.StaffID,
			MAX(rr.SoldFromMachineID),
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN DiscountTypes dt ON (rd.DiscountTypeID = dt.DiscountTypeID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 3
	AND rr.SaleSuccess = 1
	AND PackageName IS NULL
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession, dt.DiscountTypeName, rr.StaffID
	ORDER BY DiscountTypeName;
	
	-- VOIDS
	INSERT INTO @OutputTable 
	(
		GamingSession,
		VoidAmount
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.PackagePrice * rd.Quantity - (ISNULL(SalesTaxAmt, 0) * rd.Quantity) - (ISNULL(DiscountAmount, 0) * rd.Quantity)) -- DE9326
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NOT NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;
	
	--
	-- Fixed Base Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		FixedUnitSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)		
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 3 -- FIXED	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;	
	
	INSERT INTO @OutputTable
	(
		GamingSession,
		FixedUnitSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 3 -- FIXED	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;	
	
	--
	-- Tracker Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TrackerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 2 -- Tracker		
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		TrackerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 2 -- Tracker		
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;	
	
	--
	-- Traveler Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TravelerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 1 -- Traveler	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		TravelerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 1 -- Traveler	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
	
	--
	-- Traveler 2 Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		Traveler2Sales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 14 -- Traveler 2	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		Traveler2Sales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 14 -- Traveler 2		
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
				
				
	--
	-- Explorer Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		ExplorerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 4 -- Explorer
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		ExplorerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 4 -- Explorer	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;			
	
	--
	-- Pack Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID IS NULL -- Pack Sale
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID IS NULL -- Pack Sale	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;								
	
	--
	-- Ted-E Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TedeSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)		
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 17 -- TedE	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;	
	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TedeSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.StaffID = @StaffID OR @StaffID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 17 -- TedE	
	    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID) -- DE8864
	GROUP BY sp.GamingSession;	
		
	-- Device Fee
	INSERT INTO @OutputTable
	(
		DeviceFee
	)
	SELECT /*2013.03.05 knc: DE10772*/ --the whole query
  rr.DeviceFee   
   
 FROM RegisterReceipt rr  
 --JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left JOIN Staff s ON (s.StaffID = rr.StaffID)  
  left join Device d on d.DeviceID = rr.DeviceID   
  left join (select distinct(RegisterReceiptID), SessionPlayedID   from RegisterDetail) rd on rd.RegisterReceiptID = rr.RegisterReceiptID    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID  
 AND rr.DeviceFee IS NOT NULL  
 AND rr.DeviceFee <> 0   
 AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)  
    and (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)  -- Machine Mode must print activity for all staff  
 --  and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)Removed 12/26/2012 "Duplicate" - knc   
  
	--SELECT	
 --       SUM(ISNULL(rr.DeviceFee, 0))
	--FROM RegisterReceipt rr
	--WHERE (rr.StaffID = @StaffID OR @StaffID = 0)
	--AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	--AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	--AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	--AND rr.SaleSuccess = 1
	--AND rr.TransactionTypeID = 1
	--AND rr.RegisterReceiptID not in (select rr2.OriginalReceiptID
 --                                    from RegisterReceipt rr2
 --                                    where rr2.SaleSuccess = 1
 --                                       and rr2.TransactionTypeID = 2
 --                                       and rr2.OriginalReceiptID = rr.RegisterReceiptID) -- DE10484 - not voided
 --   and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID); -- DE8864
	
	
	-- Bank Calculation
	DECLARE @TmpTotalBank MONEY,
			@TotalBank MONEY;

	SELECT @TmpTotalBank = -1 * ISNULL(SUM(ctd.ctrdDefaultTotal), 0.00)
	FROM CashTransactionDetail ctd
	JOIN CashTransaction ct ON (ctd.ctrdCashTransactionID = ct.ctrCashTransactionID)
	JOIN Bank b ON (b.bkBankID = ct.ctrSrcBankID)
	WHERE ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (@Session = 0 OR ct.ctrGamingSession = @Session)
	AND ctrTransactionTypeID IN (11,17,29) -- Add 20 if we want close bank in here
	AND (b.bkStaffID = @StaffID OR @StaffID = 0)
	and b.bkBankTypeID = CASE @CashMethod 
			WHEN 1 THEN 1
			ELSE 2		-- FIX DE6959: report on regular banks only
		END
	AND (b.bkOperatorID = @OperatorID OR @OperatorID = 0)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID) -- DE8864  -- FIELD BETA FIX
	AND NOT EXISTS (SELECT * FROM CashTransaction WHERE ctrOriginalCashTransactionID = ct.ctrCashTransactionID);

	SET @TotalBank = @TmpTotalBank;

	SELECT @TmpTotalBank = ISNULL(SUM(ctd.ctrdDefaultTotal), 0.00)
	FROM CashTransactionDetail ctd
	JOIN CashTransaction ct ON (ctd.ctrdCashTransactionID = ct.ctrCashTransactionID)
	JOIN Bank b ON (b.bkBankID = ct.ctrDestBankID)
	WHERE ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (@Session = 0 OR ct.ctrGamingSession = @Session)
	AND ctrTransactionTypeID IN (11,17,29) -- Add 20 if we want close bank in here
	AND ctrdDefaultTotal > 0.0
	AND (b.bkStaffID = @StaffID OR @StaffID = 0)
	and b.bkBankTypeID = CASE @CashMethod 
			WHEN 1 THEN 1
			ELSE 2		-- FIX DE6959: report on regular banks only
		END
	AND (b.bkOperatorID = @OperatorID OR @OperatorID = 0)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID) -- DE8864  -- FIELD BETA FIX
	AND NOT EXISTS (SELECT * FROM CashTransaction WHERE ctrOriginalCashTransactionID = ct.ctrCashTransactionID);

	SET @TotalBank = @TotalBank + @TmpTotalBank	;
	
	INSERT INTO @OutputTable
	(
		BankAmount
	)
	VALUES
	(
		@TotalBank
	)	
END
ELSE
BEGIN
    -- MACHINE MODE
    
    	--Add coupon	
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		CouponAmount,
		SalesTax
	)
	
	select 
	GamingSession,
	NULL,
	sum(QuantitySold),
	0,
	StaffID,
	max(SoldFromMachineID), 
	SUM (NetSales),
	0
	 from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)
	group by GamingSession,StaffID
    
	-- Add Package Sales
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		SalesTax
		, Price	-- DE8943
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			rd.PackageName,
			SUM(rd.Quantity),
			MAX(rd.packagePrice),
			SUM(rd.PackagePrice * rd.Quantity),
			rr.StaffID,
			rr.SoldFromMachineID,
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
			, rd.PackagePrice -- DE8943	
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	AND PackageName IS NOT NULL
	GROUP BY sp.GamingSession, rd.PackageName, rr.StaffID, rr.SoldFromMachineID, rd.PackagePrice
	ORDER BY PackageName;

	-- Add Discount Sales
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		SalesTax
        , Price -- DE7636	
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			NULL,
			SUM(rd.Quantity),
			MAX(rd.PackagePrice),
			0,
			rr.StaffID,
			rr.SoldFromMachineID,
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
			, rd.PackagePrice -- DE8943	
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN DiscountTypes dt ON (rd.DiscountTypeID = dt.DiscountTypeID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	AND PackageName IS NULL
	GROUP BY sp.GamingSession, dt.DiscountTypeName, rr.StaffID, rr.SoldFromMachineID, rd.PackagePrice
	ORDER BY DiscountTypeName;

	-- Add Package Returns
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		ReturnAmount,
		SalesTax,
		Price
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			rd.PackageName,
			SUM(-1 * rd.Quantity),
			MAX(rd.PackagePrice),
			SUM(rd.PackagePrice * rd.Quantity),
			rr.StaffID,
			rr.SoldFromMachineID,
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(rd.PackagePrice * rd.Quantity),
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
			, rd.PackagePrice -- DE8943	
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 3
	AND rr.SaleSuccess = 1
	AND PackageName IS NOT NULL
	GROUP BY sp.GamingSession, rd.PackageName, rr.StaffID, rr.SoldFromMachineID, rd.PackagePrice
	ORDER BY PackageName;

	-- Add Discount Returns
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackageName,
		PackageQuantity,
		PackagePrice,
		PackageTotal,
		StaffID,
		SoldFromMachine,
		DiscountAmount,
		ReturnAmount,
		SalesTax, 
		Price
	)
	SELECT	
			ISNULL(sp.GamingSession, 0),
			NULL,
			SUM(-1 * rd.Quantity),
			MAX(rd.packagePrice),
			0,
			rr.StaffID,
			rr.SoldFromMachineID,
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.DiscountAmount, 0) * rd.Quantity),		-- DE9326
			SUM(ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity)
			, rd.PackagePrice -- DE8943	
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN DiscountTypes dt ON (rd.DiscountTypeID = dt.DiscountTypeID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NULL
	AND rr.TransactionTypeID = 3
	AND rr.SaleSuccess = 1
	AND PackageName IS NULL
	GROUP BY sp.GamingSession, dt.DiscountTypeName, rr.StaffID, rr.SoldFromMachineID, rd.PackagePrice
	ORDER BY DiscountTypeName;
	
	INSERT INTO @OutputTable 
	(
		GamingSession,
		VoidAmount
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.PackagePrice * rd.Quantity - (ISNULL(SalesTaxAmt, 0) * rd.Quantity) - (ISNULL(DiscountAmount, 0) * rd.Quantity))-- DE9326
	FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (rd.SessionPlayedID = sp.SessionPlayedID)
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND (sp.GamingSession = @Session OR @Session = 0)
	AND rd.VoidedRegisterReceiptID IS NOT NULL
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1
	GROUP BY sp.GamingSession;
	
	--
	-- Fixed Base Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		FixedUnitSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)		
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 3 -- FIXED	
	GROUP BY sp.GamingSession;		
	
	INSERT INTO @OutputTable
	(
		GamingSession,
		FixedUnitSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 3 -- FIXED	
	GROUP BY sp.GamingSession;		
	
	--
	-- Tracker Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TrackerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 2 -- Tracker		
	GROUP BY sp.GamingSession;
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		TrackerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 2 -- Tracker		
	GROUP BY sp.GamingSession;	
	
	--
	-- Traveler Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TravelerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 1 -- Traveler	
	GROUP BY sp.GamingSession	;	
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		TravelerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 1 -- Traveler	
	GROUP BY sp.GamingSession;	
	
	--
	-- Traveler 2 Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		Traveler2Sales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 14 -- Traveler 2	
	GROUP BY sp.GamingSession;		
		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		Traveler2Sales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 14 -- Traveler 2		
	GROUP BY sp.GamingSession;	
	
	--
	-- Explorer Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		ExplorerSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 4 -- Explorer
	GROUP BY sp.GamingSession;		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		ExplorerSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 4 -- Explorer	
	GROUP BY sp.GamingSession;	
	
	--
	-- Pack Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID IS NULL -- Pack Sale
	GROUP BY sp.GamingSession;		
		
	INSERT INTO @OutputTable
	(
		GamingSession,
		PackSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID IS NULL -- Pack Sale	
	GROUP BY sp.GamingSession;			
	
	--
	-- Ted-E Sales Calculation
	--	
	INSERT INTO @OutputTable
	(
		GamingSession,
		TedeSales
	)
	SELECT	sp.GamingSession,
			SUM(rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)		
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 1
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 17 -- TedE
	GROUP BY sp.GamingSession;		
	
	INSERT INTO @OutputTable
	(
		GamingSession,
		FixedUnitSales
	)
	SELECT	sp.GamingSession,
			SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)	
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	Where (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
		AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
		AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
		AND (sp.GamingSession = @Session OR @Session = 0)
		AND rr.SaleSuccess = 1
		AND rr.TransactionTypeID = 3
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
		AND rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
		AND	dpr.deviceID = 17 -- TedE	
	GROUP BY sp.GamingSession;		
	
	-- Device Fee
	INSERT INTO @OutputTable
	(
		DeviceFee
	)
	SELECT	
			SUM(ISNULL(rr.DeviceFee, 0))
	FROM RegisterReceipt rr
	WHERE (rr.SoldFromMachineID = @MachineID OR @MachineID = 0)
	AND (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime))
	AND (rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	AND (rr.OperatorID = @OperatorID OR @OperatorID = 0)
	AND rr.TransactionTypeID = 1
	AND rr.SaleSuccess = 1;
	
	
	-- Bank Calculation
	DECLARE @TmpTotalBank2 MONEY,
			@TotalBank2 MONEY;

	SELECT @TmpTotalBank2 = -1 * ISNULL(SUM(ctd.ctrdDefaultTotal), 0.00)
	FROM CashTransactionDetail ctd
	JOIN CashTransaction ct ON (ctd.ctrdCashTransactionID = ct.ctrCashTransactionID)
	JOIN Bank b ON (b.bkBankID = ct.ctrSrcBankID)
	WHERE ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (@Session = 0 OR ct.ctrGamingSession = @Session)
	AND ctrTransactionTypeID IN (11,17,29) -- Add 20 if we want close bank in here
	--AND ctrdDefaultTotal < 0.0
	AND (b.bkMachineID = @MachineID OR @MachineID = 0)
	AND (b.bkOperatorID = @OperatorID OR @OperatorID = 0);

	SET @TotalBank2 = @TmpTotalBank2;

	SELECT @TmpTotalBank2 = ISNULL(SUM(ctd.ctrdDefaultTotal), 0.00)
	FROM CashTransactionDetail ctd
	JOIN CashTransaction ct ON (ctd.ctrdCashTransactionID = ct.ctrCashTransactionID)
	JOIN Bank b ON (b.bkBankID = ct.ctrDestBankID)
	WHERE ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (@Session = 0 OR ct.ctrGamingSession = @Session)
	AND ctrTransactionTypeID IN (11,17,29) -- Add 20 if we want close bank in here
	AND ctrdDefaultTotal > 0.0
	AND (b.bkMachineID = @MachineID OR @MachineID = 0)
	AND (b.bkOperatorID = @OperatorID OR @OperatorID = 0);

	SET @TotalBank2 = @TotalBank2 + @TmpTotalBank2;
	
	INSERT INTO @OutputTable
	(
		BankAmount
	)
	VALUES
	(
		@TotalBank2
	)		
							
END

SELECT	isnull(GamingSession, 0) AS GamingSession,
		PackageName AS PackageName,
		SUM(PackageQuantity) AS PackageQuantity,
		MAX(PackagePrice) as PackagePrice,
		SUM(PackageTotal) AS PackageTotal,
		SoldFromMachine AS SoldFromMachine,
		(s.FirstName + ' ' + s.LastName) AS StaffName,
		0.00 AS DiscountAmount,
		0.00 AS CouponAmount,
		0.00 AS VoidAmount,
		SUM(ISNULL(ReturnAmount, 0)) AS ReturnAmount,
		NULL AS FixedUnitSales,
		NULL AS TravelerSales,
		NULL AS Traveler2Sales,
		NULL AS TrackerSales,
		NULL AS ExplorerSales,
		NULL AS TedeSales,
		NULL AS PackSales,
		SUM(ISNULL(SalesTax, 0)) AS SalesTax,
		NULL AS DeviceFee,
		NULL AS BankAmount
		, SUM(isnull(Price, 0)) as Price	-- DE7636
FROM
@OutputTable ot
JOIN Staff s ON (ot.StaffID = s.StaffID)
GROUP BY GamingSession, PackageName, SoldFromMachine, s.FirstName, s.LastName
UNION
SELECT	isnull(GamingSession, 0) AS GamingSession,
		NULL AS PackageName,
		NULL AS PackageQuantity,
		NULL as PackagePrice,
		NULL AS PackageTotal,
		NULL AS SoldFromMachine,
		NULL AS StaffName,
		SUM(ISNULL(DiscountAmount, 0)) AS DiscountAmount,
		SUM(ISNULL(CouponAmount, 0)) AS CouponAmount,
		SUM(ISNULL(VoidAmount, 0)) AS VoidAmount,
		NULL AS ReturnAmount,
		NULL AS FixedUnitSales,
		NULL AS TravelerSales,
		NULL AS Traveler2Sales,
		NULL AS TrackerSales,
		NULL AS ExplorerSales,
		NULL AS TedeSales,
		NULL AS PackSales,
		NULL AS SalesTax,
		SUM(ISNULL(DeviceFee, 0)) AS DeviceFee,
		SUM(ISNULL(BankAmount, 0)) AS BankAmount
		, null as Price
FROM @OutputTable ot
GROUP BY GamingSession
UNION
SELECT	isnull(GamingSession, 0) AS GamingSession,
		NULL AS PackageName,
		NULL AS PackageQuantity,
		null as PackagePrice,
		NULL AS PackageTotal,
		NULL AS SoldFromMachine,
		NULL AS StaffName,
		NULL AS DiscountAmount,
		NULL AS CouponAmount,
		NULL AS VoidAmount,
		NULL AS ReturnAmount,
		SUM(ISNULL(FixedUnitSales, 0)) AS FixedUnitSales,
		SUM(ISNULL(TravelerSales, 0)) AS TravelerSales,
		SUM(ISNULL(Traveler2Sales, 0)) AS Traveler2Sales,
		SUM(ISNULL(TrackerSales, 0)) AS TrackerSales,
		SUM(ISNULL(ExplorerSales, 0)) AS ExplorerSales,
		SUM(ISNULL(TedeSales, 0)) As TedeSales,
		SUM(ISNULL(PackSales, 0)) AS PackSales,
		NULL AS SalesTax,
		NULL AS DeviceFee,
		NULL AS BankAmount
		, null as Price
FROM @OutputTable ot
GROUP BY GamingSession			
ORDER BY GamingSession, StaffName, PackageName;


SET NOCOUNT OFF


















GO

