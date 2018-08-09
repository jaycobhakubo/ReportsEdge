USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperInventoryNotRetired]    Script Date: 01/28/2014 15:52:28 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperInventoryNotRetired]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperInventoryNotRetired]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperInventoryNotRetired]    Script Date: 01/28/2014 15:52:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-----------------------------------------------------------------------------------------------------------------
-- 2014.01.28 tmp: Copied from spRptInvCenterOnHand, changed to report paper products only
-----------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spRptPaperInventoryNotRetired]
(	@OperatorID as int
)	
	 
AS

SET NOCOUNT ON;	

SET @OperatorID = NULLIF(@OperatorID, 0)

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
	AND ii.iiRetiredDate IS NULL
	And pdi.ProductTypeID = '16'  --Paper
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
	AND ii.iiRetiredDate IS NULL
	And pdi.ProductTypeID = '16'  --Paper
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
	AND ii.iiRetiredDate IS NULL
	And pdi.ProductTypeID = '16'  --Paper
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
    OperatorId  int,
    ManufId     int,
    VendorId    int,
    ProdItemId  int,
    ManufName   nvarchar(64),
    VendorName  nvarchar(100),
    ProdName    nvarchar(64),
    InvLoc      nvarchar(64),
    InvNbr      nvarchar(30),
    SerialNbr   nvarchar(30),
    RangeStart  int,
    RangeEnd    int,
    FirstIssued datetime,
    LastIssued  datetime,
    Retired     datetime,
    TaxId       nvarchar(30),
    CardCut     nvarchar(30),
    Up          int,
    StartCount  int,
    Damaged     bigint,
    Skipped     bigint,
    CurrCount   bigint,
    Price       money,
    InvCost     money,
    isPaper		int
);

-- Insert the results into the table
INSERT INTO @Results
(  
	  OperatorId
	, ManufId
	, VendorId
	, ProdItemId
	, ManufName, VendorName, ProdName, InvLoc
	, InvNbr, SerialNbr, RangeStart, RangeEnd
	, FirstIssued, LastIssued, Retired, TaxId     
	, CardCut, Up
	, StartCount, Damaged, Skipped, CurrCount
	, Price, InvCost
	, isPaper
)
SELECT pdi.OperatorID
	, im.imInvManufacturerID
	, v.VendorID
	, pdi.ProductItemID
	, ISNULL(im.imInvManufacturerName, 'Unknown Manufacturer')
	, ISNULL(v.VendorName, 'Unknown Vendor')
	, pdi.ItemName
	, il.ilInvLocationName
	, ii.iiInvoiceNo
	, ii.iiSerialNo
	, ii.iiRangeStart
	, ii.iiRangeEnd
	, ii.iiFirstIssueDate
	, ii.iiLastIssueDate
	, ii.iiRetiredDate
	, ii.iiTaxID
	, cc.ccCardCutName
	, ii.iiUp
	, ii.iiStartCount
	, lc.damageCount
	, lc.skipCount
	, lc.CurrentCount
	, ii.iiPricePerItem
	, CASE WHEN ISNULL(ii.iiStartCount, 0) = 0 THEN 0
		ELSE (CONVERT(decimal, ii.iiCostPerItem) / CONVERT(decimal, ii.iiStartCount)) * lc.CurrentCount END
	, CASE WHEN pdi.ProductTypeID = 16 THEN 1 ELSE 0 END -- PaperSales
FROM @InvItemLocCounts lc
	JOIN InventoryItem ii ON (ii.iiInventoryItemID = lc.itemID)
	JOIN ProductItem pdi ON (pdi.ProductItemID = ii.iiProductItemID)
	JOIN InvLocations il ON (il.ilInvLocationID = lc.locationID)
	LEFT JOIN InvManufacturer im ON (im.imInvManufacturerID = ii.iiManufacturerID)
	LEFT JOIN Vendor v ON (v.VendorID = ii.iiVendorID)
	LEFT JOIN CardCuts cc ON (ii.iiCardCutID = cc.ccCardCutID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND il.ilInvLocationTypeID IN (1, 2)
	AND ii.iiRetiredDate IS NULL
	And pdi.ProductTypeID = '16'  --Paper


-- DEBUG
--SELECT * FROM @Results
--SELECT * FROM InventoryItem
-- END DEBUG

-- Return resultset to the report
Select * 
from @Results
order by OperatorId, ManufName, VendorName, ProdName, InvLoc;



















GO

