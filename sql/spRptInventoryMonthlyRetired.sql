USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryMonthlyRetired]    Script Date: 01/30/2014 14:50:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryMonthlyRetired]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryMonthlyRetired]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryMonthlyRetired]    Script Date: 01/30/2014 14:50:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-----------------------------------------------------------------------------------------------------------------
-- 2014.01.30 tmp: Copied logic from spRptPaperInventoryRetiredOnly
-----------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spRptInventoryMonthlyRetired]
(	@OperatorID as int,
	@Month Int,
	@Year Int
)	
	 
AS

SET NOCOUNT ON;	

---- Testing
--Declare @OperatorID Int,

--SET @OperatorID = NULLIF(@OperatorID, 0)
--SET @Month = 8
--SET @Year = 2013

DECLARE @Damages TABLE
(
	itemID int,
	locationID int,
	damageCount bigint
);

-- Get all relevant damages
INSERT INTO @Damages
(
	itemID,
	locationID,
	damageCount
)
SELECT it.ivtInventoryItemID
	, itd2.ivdInvLocationID
	, -SUM(CONVERT(bigint, itd.ivdDelta) + CONVERT(bigint, itd2.ivdDelta))
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InvTransactionDetail itd2 ON (it.ivtInvTransactionID = itd2.ivdInvTransactionID AND itd.ivdInvTransactionDetailID < itd2.ivdInvTransactionDetailID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
WHERE it.ivtTransactionTypeID = 27 -- Damage transaction
	AND (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NOT NULL
GROUP BY it.ivtInventoryItemID, itd2.ivdInvLocationID

-- DEBUG
--SELECT * FROM @Damages
-- END DEBUG

DECLARE @Skips TABLE
(
	itemID int,
	locationID int,
	skipCount bigint
);

-- Get all relevant damages
INSERT INTO @Skips
(
	itemID,
	locationID,
	skipCount
)
SELECT it.ivtInventoryItemID
	, itd2.ivdInvLocationID
	, -SUM(CONVERT(bigint, itd.ivdDelta) + CONVERT(bigint, itd2.ivdDelta))
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InvTransactionDetail itd2 ON (it.ivtInvTransactionID = itd2.ivdInvTransactionID AND itd.ivdInvTransactionDetailID < itd2.ivdInvTransactionDetailID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
WHERE it.ivtTransactionTypeID = 23 -- Skip transaction
	AND (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NOT NULL
GROUP BY it.ivtInventoryItemID, itd2.ivdInvLocationID

-- DEBUG
--SELECT * FROM @Skips
-- END DEBUG

DECLARE @InvItemLocCounts TABLE
(
	itemID int,
	locationID int,
	damageCount bigint,
	skipCount bigint,
	currentCount bigint
);

INSERT INTO @InvItemLocCounts
(
	itemID,
	locationID,
	damageCount,
	skipCount,
	currentCount
)
SELECT it.ivtInventoryItemID
	, itd.ivdInvLocationID
	, 0 -- damage
	, 0 -- skip
	, SUM(CONVERT(bigint, itd.ivdDelta)) -- current count
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
	LEFT JOIN @Damages d ON (d.itemID = it.ivtInventoryItemID AND d.locationID = itd.ivdInvLocationID)
	LEFT JOIN @Skips s ON (s.itemID = it.ivtInventoryItemID AND s.locationID = itd.ivdInvLocationID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NOT NULL
GROUP BY it.ivtInventoryItemID, itd.ivdInvLocationID

-- Update the damages column
UPDATE @InvItemLocCounts
SET damageCount = d.damageCount
FROM @InvItemLocCounts lc
	JOIN @Damages d ON (d.itemID = lc.itemID AND d.locationID = lc.locationID)

-- Update the skips column
UPDATE @InvItemLocCounts
SET skipCount = s.skipCount
FROM @InvItemLocCounts lc
	JOIN @Skips s ON (s.itemID = lc.itemID AND s.locationID = lc.locationID)

-- DEBUG
--SELECT * FROM @InvItemLocCounts
-- END DEBUG

DECLARE @Results TABLE
(
    ManufName   nvarchar(64),
    ProdType	nvarchar(64),
    ProdName    nvarchar(64),
    InvLoc      nvarchar(64),
    InvNbr      nvarchar(30),
    SerialNbr   nvarchar(30),
    RangeStart  int,
    RangeEnd    int,
    ReceivedDate datetime,
    FirstIssued datetime,
    LastIssued  datetime,
    Retired     datetime,
    CardCut     nvarchar(30),
    Up          int,
    StartCount  int,
    Damaged     bigint,
    Skipped     bigint,
    CurrCount   bigint,
    Cost        money,
    InvCost     money
);

-- Insert the results into the table
INSERT INTO @Results
(  
	  ManufName
	, ProdType  
	, ProdName
	, InvLoc
	, InvNbr
	, SerialNbr
	, RangeStart
	, RangeEnd
	, ReceivedDate
	, FirstIssued
	, LastIssued
	, Retired
	, CardCut
	, Up
	, StartCount
	, Damaged
	, Skipped
	, CurrCount
	, Cost
	, InvCost
)
SELECT  ISNULL(im.imInvManufacturerName, 'N/A')
	, pt.ProductType
	, pdi.ItemName
	, il.ilInvLocationName
	, ii.iiInvoiceNo
	, ii.iiSerialNo
	, ii.iiRangeStart
	, ii.iiRangeEnd
	, ii.iiReceivedDate
	, ii.iiFirstIssueDate
	, ii.iiLastIssueDate
	, ii.iiRetiredDate
	, cc.ccCardCutName
	, ii.iiUp
	, ii.iiStartCount
	, lc.damageCount
	, lc.skipCount
	, lc.CurrentCount
	, CASE WHEN ISNULL(ii.iiStartCount, 0) = 0 THEN 0
		ELSE (CONVERT(decimal, ii.iiCostPerItem) / CONVERT(decimal, ii.iiStartCount)) END
	, CASE WHEN ISNULL(ii.iiStartCount, 0) = 0 THEN 0
		ELSE (CONVERT(decimal, ii.iiCostPerItem) / CONVERT(decimal, ii.iiStartCount)) * lc.CurrentCount END
FROM @InvItemLocCounts lc
	JOIN InventoryItem ii ON (ii.iiInventoryItemID = lc.itemID)
	JOIN ProductItem pdi ON (pdi.ProductItemID = ii.iiProductItemID)
	JOIN ProductType pt on (pt.ProductTypeID = pdi.ProductTypeID)
	JOIN InvLocations il ON (il.ilInvLocationID = lc.locationID)
	LEFT JOIN InvManufacturer im ON (im.imInvManufacturerID = ii.iiManufacturerID)
	LEFT JOIN CardCuts cc ON (ii.iiCardCutID = cc.ccCardCutID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND il.ilInvLocationTypeID IN (1, 2)
	AND DATEPART(Month, ii.iiRetiredDate) = @Month
	AND DATEPART(Year, ii.iiRetiredDate) = @Year


-- DEBUG
--SELECT * FROM @Results
--SELECT * FROM InventoryItem
-- END DEBUG

-- Return resultset to the report
Select * 
from @Results
order by ProdType, ProdName, SerialNbr, InvLoc;

SET NOCOUNT OFF


GO

