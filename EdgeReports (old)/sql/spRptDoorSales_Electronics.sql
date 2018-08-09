USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Electronics]    Script Date: 08/02/2012 13:54:25 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales_Electronics]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales_Electronics]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Electronics]    Script Date: 08/02/2012 13:54:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptDoorSales_Electronics] 
-- ============================================================================
-- Author:		Louis J. Landerman
-- Description:	<>
-- 2011.07.18 bjs: DE8882 invalid rate fee after transfer
-- 2011.08.05 bjs: US1902 add prod group param
-- 2011.09.01 bjs: cards sold/played too high
-- 2011.11.30 bjs: DE9706 invalid cards played when specifying ALL groups
-- 2012.02.09 jkn: DE9706/TA10839 Remove the product group data
--	this was causing problems when attempting to calculate totals
-- 2012.02.21 jkn: DE10136 pack sales were being counted improperly
-- 2012.08.02 jkn: DE10580 count all of the cards that are returned since
--  the same card number can be used for a different game and the distinct
--  would miss these cards creating an invalid card count.
-- ============================================================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int
AS
	
SET NOCOUNT ON

-- Move logic from Crystal command to here...
declare @taxRate money;
select @taxRate = (SalesTax / 100.0) from Hall where HallID = (select top 1 HallID from Hall);
print @taxRate;


DECLARE @ResultsUnits TABLE
(
	DeviceName NVARCHAR(32),
	CardsSold INT,
	UnitSales MONEY,
	UnitsSold INT
);

-- Create a lookup to get device type for each receipt
DECLARE @TempDevicePerReceiptDeviceSummary TABLE
(
	registerReceiptID INT,
	deviceID INT,
	soldToMachineID INT,
	unitNumber INT
);

with TEMP( registerReceiptID, deviceID, soldToMachineID, unitNumber) as
(
SELECT	
	rr.RegisterReceiptID,
	(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
	(SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
	(SELECT TOP 1 ulUnitNumber FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)
FROM RegisterReceipt rr
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
Where 
	rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
)
INSERT INTO @TempDevicePerReceiptDeviceSummary
	(
	registerReceiptID,
	deviceID,
	soldToMachineID,
	unitNumber
	)
select distinct *					-- bjs 9/1/11 cards sold/played too high
from TEMP 
where deviceID is not null;


-- Get the cards sold, but only for non-continued games and filter out games that have been replayed (DE7209).
WITH SessionGames (SessionGamesPlayedID)
AS
(
	SELECT MAX(SessionGamesPlayed.SessionGamesPlayedID)
	FROM SessionPlayed 
	JOIN SessionGamesPlayed ON (SessionPlayed.SessionPlayedID = SessionGamesPlayed.SessionPlayedID)
	WHERE 
	SessionPlayed.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND SessionPlayed.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND SessionPlayed.OperatorID = @OperatorID
	AND SessionGamesPlayed.IsContinued = 0
	GROUP BY SessionGamesPlayed.SessionPlayedID, SessionGamesPlayed.GameSeqNo, SessionGamesPlayed.DisplayGameNo, SessionGamesPlayed.DisplayPartNo, SessionGamesPlayed.GameName, SessionGamesPlayed.IsContinued
)
INSERT INTO @ResultsUnits
(
	DeviceName,
	CardsSold
	, UnitSales, UnitsSold      -- ensure we have no nulls for report summaries to work!
)
SELECT	ISNULL(d.DeviceType, 'Pack'),
--		COUNT(distinct bcd.bcdCardNo)   -- DE9706
		COUNT(bcd.bcdCardNo)   -- DE9706
		, 0, 0
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	LEFT JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
	JOIN BingoCardHeader bch ON (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)
	JOIN BingoCardDetail bcd ON (bcd.bcdSessionGamesPlayedID = bch.bchSessionGamesPlayedID AND bcd.bcdMasterCardNo = bch.bchMasterCardNo)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	AND (bch.bchSessionGamesPlayedID IN (SELECT * FROM SessionGames))
GROUP BY d.DeviceType;

--select * from @ResultsUnits

-- Get Unit Sales
INSERT INTO @ResultsUnits
(
	DeviceName,
	UnitSales
	, CardsSold, UnitsSold
)
SELECT	ISNULL(d.DeviceType, 'Pack'),
		SUM(isnull(rd.Quantity, 0) * isnull(rdi.Qty, 0) * isnull(rdi.Price, 0))		
		, 0, 0
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	LEFT JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY d.DeviceType;

-- Get Units Sold
INSERT INTO @ResultsUnits
	(
		DeviceName,
		UnitsSold
		, CardsSold, UnitSales
	)
SELECT	ISNULL(d.DeviceType, 'Pack'),
		CASE 
			WHEN d.DeviceID < 3 THEN COUNT (DISTINCT isnull(dpr.unitNumber, 0))
--			ELSE COUNT( DISTINCT isnull(dpr.soldToMachineID, 0))
			else count(distinct(dpr.soldToMachineId)) -- DE10136
		END
		, 0, 0
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	LEFT JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)	
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY d.DeviceType, d.DeviceID;

DECLARE @Results TABLE
(
	DeviceName NVARCHAR(32),
	CardsSold INT,
	UnitSales MONEY,
	UnitsSold INT,
	UnitFee MONEY,
	TotFee money		        -- DE8882
	, GroupName nvarchar(64)    -- DE9706
	, TaxRate money             -- DE9706
);

INSERT INTO @Results
(
	DeviceName,
	CardsSold,
	UnitSales,
	UnitsSold,
	TotFee
	, TaxRate
)
SELECT  DeviceName,
		SUM(isnull(CardsSold, 0)),
		SUM(isnull(UnitSales, 0)),
		SUM(isnull(UnitsSold, 0)), 
		0
		, @taxRate          -- DE9706
FROM @ResultsUnits
GROUP BY DeviceName;


UPDATE @Results
SET UnitFee = ddf.ddfDeviceFee
FROM @Results r
	JOIN Device d ON (d.DeviceType = r.DeviceName)
	JOIN DistributorDeviceFees ddf ON (ddf.ddfDeviceID = d.DeviceID)
WHERE ddf.ddfOperatorID = @OperatorID
	AND ddf.ddfDeviceID = d.DeviceID
	AND ddf.ddfDistDeviceFeeTypeID = 1
	AND r.UnitsSold >= ddf.ddfMinRange
	AND r.UnitsSold <= ddf.ddfMaxRange

UPDATE @Results SET UnitFee = 0
WHERE UnitFee IS NULL;

-- DE8882
update @Results set totFee = (UnitFee * UnitsSold);

-- Return our resultset
SELECT * FROM @Results order by DeviceName;      -- DE9706

SET NOCOUNT OFF









GO

