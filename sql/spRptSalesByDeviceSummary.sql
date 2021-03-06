USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSummary]    Script Date: 12/26/2012 15:17:01 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByDeviceSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByDeviceSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSummary]    Script Date: 12/26/2012 15:17:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE  [dbo].[spRptSalesByDeviceSummary]
-- =============================================
-- Author:		<Louis J. Landerman>
-- Description:	<>
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@Session	AS	INT,
	@StaffID	AS	INT = 0
AS

-- ==================
-- Test code
--declare 
--@OperatorID	INT ,
--@StartDate	DATETIME ,
--@EndDate	DATETIME ,
--@Session	INT ,
--@StaffID  int 

--set @OperatorID	 = 1
--set @StartDate	 = '1/1/1900 00:00:00'
--set @EndDate	 = '1/1/2014 00:00:00'
--set @Session	 = 0
--set @StaffID   = 24


-- ====================

SET NOCOUNT ON

-- Results table	
CREATE TABLE #TempRptSalesByDeviceSummary
	(
		FixedSales			MONEY,
		FixedQty			INT,
		TrackerSales		MONEY,
		TrackerQty			INT,
		TravelerSales		MONEY,
		TravelerQty			INT,
		Traveler2Sales		MONEY,
		Traveler2Qty		INT,
		ExplorerSales		MONEY,
		ExplorerQty			INT,
		PackSales			MONEY,
		TransCnt			INT	
	)
		
--
-- Populate Device Lookup Table to matchup a device with a register receipt using
-- the UnLockLog for lookups.
--
CREATE TABLE #TempDevicePerReceiptDeviceSummary
	(
		registerReceiptID	INT,
		deviceID			INT,
		soldToMachineID		INT,
		unitNumber			INT
	)
	
INSERT INTO #TempDevicePerReceiptDeviceSummary
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
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)		

	


--
-- Fixed Base Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	FixedSales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 3 -- FIXED	
	and (@StaffID = 0 or rr.StaffID = @StaffID)	
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	FixedSales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 3 -- FIXED	
	and (@StaffID = 0 or rr.StaffID = @StaffID)	




	
--
-- Tracker Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	TrackerSales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 2 -- Tracker	
	and (@StaffID = 0 or rr.StaffID = @StaffID)	
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	TrackerSales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 2 -- Tracker		
	and (@StaffID = 0 or rr.StaffID = @StaffID)





--
-- Traveler Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	TravelerSales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 1 -- Traveler	
	and (@StaffID = 0 or rr.StaffID = @StaffID)	
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	TravelerSales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 1 -- Traveler	
	and (@StaffID = 0 or rr.StaffID = @StaffID)





--
-- Traveler 2 Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	Traveler2Sales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 14 -- Traveler 2	
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	Traveler2Sales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 14 -- Traveler 2		
	and (@StaffID = 0 or rr.StaffID = @StaffID)





--
-- Explorer Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	ExplorerSales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 4 -- Explorer
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	ExplorerSales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID = 4 -- Explorer		
	and (@StaffID = 0 or rr.StaffID = @StaffID)





--
-- Pack Sales Calculation
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	PackSales
)
SELECT	SUM(rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID IS NULL -- Pack Sale
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
INSERT INTO #TempRptSalesByDeviceSummary
(
	PackSales
)
SELECT	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 3
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	dpr.deviceID IS NULL -- Pack Sale	
	and (@StaffID = 0 or rr.StaffID = @StaffID)		
	
	
	
	
	
--
-- Fixed Base Number Of Units
--		
CREATE TABLE #TempResTable
(
	soldToMachine		INT,
	gamingSession		INT,
	gamingDate			DATETIME
)
	
INSERT INTO #TempResTable
(
	soldToMachine,
	gamingSession,
	gamingDate
)
SELECT DISTINCT tds.soldToMachineID, sp.GamingSession, sp.GamingDate
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary tds ON (tds.registerReceiptID = rr.registerReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	tds.deviceID = 3 -- FIXED	
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
	--
	-- Our quantity is the number of distinct dates, sessions, and machine ids used.
	--
	INSERT INTO #TempRptSalesByDeviceSummary
	(
		FixedQty
	)
	SELECT COUNT(*) FROM #TempResTable
	
DROP TABLE #TempResTable	





--
-- Explorer Number Of Units
--		
CREATE TABLE #TempResTable2
(
	soldToMachine		INT,
	gamingSession		INT,
	gamingDate			DATETIME
)
	
INSERT INTO #TempResTable2
(
	soldToMachine,
	gamingSession,
	gamingDate
)
SELECT DISTINCT tds.soldToMachineID, sp.GamingSession, sp.GamingDate
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary tds ON (tds.registerReceiptID = rr.registerReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	tds.deviceID = 4 -- Explorer
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	--
	-- Our quantity is the number of distinct dates, sessions, and machine ids used.
	--
	INSERT INTO #TempRptSalesByDeviceSummary
	(
		ExplorerQty		
	)
	SELECT COUNT(*) FROM #TempResTable2
	
DROP TABLE #TempResTable2	





--
-- Traveler 2 Number Of Units
--		
CREATE TABLE #TempResTable3
(
	soldToMachine		INT,
	gamingSession		INT,
	gamingDate			DATETIME
)
	
INSERT INTO #TempResTable3
(
	soldToMachine,
	gamingSession,
	gamingDate
)
SELECT DISTINCT tds.soldToMachineID, sp.GamingSession, sp.GamingDate
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary tds ON (tds.registerReceiptID = rr.registerReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	tds.deviceID = 14 -- Traveler 2
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
	--
	-- Our quantity is the number of distinct dates, sessions, and machine ids used.
	--
	INSERT INTO #TempRptSalesByDeviceSummary
	(
		Traveler2Qty		
	)
	SELECT COUNT(*) FROM #TempResTable3
	
DROP TABLE #TempResTable3	





--
-- Traveler 2 Number Of Units
--		
CREATE TABLE #TempResTable4
(
	unitNumber			INT,
	gamingSession		INT,
	gamingDate			DATETIME
)
	
INSERT INTO #TempResTable4
(
	unitNumber,
	gamingSession,
	gamingDate
)
SELECT DISTINCT tds.unitNumber, sp.GamingSession, sp.GamingDate
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary tds ON (tds.registerReceiptID = rr.registerReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	tds.deviceID = 1 -- Traveler
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	
	--
	-- Our quantity is the number of distinct dates, sessions, and machine ids used.
	--
	INSERT INTO #TempRptSalesByDeviceSummary
	(
		TravelerQty		
	)
	SELECT COUNT(*) FROM #TempResTable4
	
DROP TABLE #TempResTable4	





--
-- Traveler 2 Number Of Units
--		
CREATE TABLE #TempResTable5
(
	unitNumber			INT,
	gamingSession		INT,
	gamingDate			DATETIME
)
	
INSERT INTO #TempResTable5
(
	unitNumber,
	gamingSession,
	gamingDate
)
SELECT DISTINCT tds.unitNumber, sp.GamingSession, sp.GamingDate
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN #TempDevicePerReceiptDeviceSummary tds ON (tds.registerReceiptID = rr.registerReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND	tds.deviceID = 2 -- Tracker
	and (@StaffID = 0 or rr.StaffID = @StaffID)
	--
	-- Our quantity is the number of distinct dates, sessions, and machine ids used.
	--
	INSERT INTO #TempRptSalesByDeviceSummary
	(
		TrackerQty		
	)
	SELECT COUNT(*) FROM #TempResTable5
	
DROP TABLE #TempResTable5	





--
-- Transaction Count
--	
INSERT INTO #TempRptSalesByDeviceSummary
(
	TransCnt
)
SELECT COUNT(DISTINCT rr.RegisterReceiptID)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)	
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID IN (1,2,3)
	AND rr.OperatorID = @OperatorID
	AND (@Session = 0 or sp.GamingSession = @Session)
	and (@StaffID = 0 or rr.StaffID = @StaffID)
		

-- Select out our results for the report			
SELECT	ISNULL(SUM(FixedSales),0.00) AS FixedSales,
		ISNULL(SUM(FixedQty),0) AS FixedQty,
		ISNULL(SUM(TrackerSales),0.00) AS TrackerSales,
		ISNULL(SUM(TrackerQty),0) AS TrackerQty,
		ISNULL(SUM(TravelerSales),0.00) AS TravelerSales,
		ISNULL(SUM(TravelerQty),0) AS TravelerQty,
		ISNULL(SUM(Traveler2Sales),0.00) AS Traveler2Sales,
		ISNULL(SUM(Traveler2Qty),0) AS Traveler2Qty,
		ISNULL(SUM(ExplorerSales),0.00) AS ExplorerSales,
		ISNULL(SUM(ExplorerQty),0) AS ExplorerQty,
		ISNULL(SUM(PackSales),0.00) AS PackSales,
		ISNULL(SUM(TransCnt),0) AS TransCnt
FROM #TempRptSalesByDeviceSummary

DROP TABLE #TempRptSalesByDeviceSummary
DROP TABLE #TempDevicePerReceiptDeviceSummary
    
SET NOCOUNT OFF

GO


