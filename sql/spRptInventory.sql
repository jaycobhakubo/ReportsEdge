USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventory]    Script Date: 02/05/2014 09:24:20 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventory]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventory]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventory]    Script Date: 02/05/2014 09:24:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptInventory] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Current inventory levels>
-- =============================================
	@OperatorID	AS INT
AS
	
SET NOCOUNT ON

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
GROUP BY it.ivtInventoryItemID, itd2.ivdInvLocationID

-- DEBUG
--SELECT * FROM @Skips
-- END DEBUG

DECLARE @Adjustments TABLE
(
	itemID int,
	locationID int,
	adjCount bigint
);

INSERT INTO @Adjustments
(
	itemID,
	locationID,
	adjCount
)
SELECT it.ivtInventoryItemID
	, itd.ivdInvLocationID
	, SUM(CONVERT(bigint, itd.ivdDelta)) -- adjustment count
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
WHERE it.ivtTransactionTypeID in (21, 22, 30) --Move,  Manual Inventory Adjustments, Retired
	And (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NULL
GROUP BY it.ivtInventoryItemID, itd.ivdInvLocationID

DECLARE @Consumed TABLE
(
	itemID int,
	locationID int,
	consumedCount bigint
);

INSERT INTO @Consumed
(
	itemID,
	locationID,
	consumedCount
)
SELECT it.ivtInventoryItemID
	, itd.ivdInvLocationID
	, (SUM(CONVERT(bigint, itd.ivdDelta)) * -1) -- consumed count
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
WHERE it.ivtTransactionTypeID in (1, 2, 3, 25) -- Sale, Sale Void, Return, Issue
	And (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NULL
GROUP BY it.ivtInventoryItemID, itd.ivdInvLocationID

DECLARE @InvItemLocCounts TABLE
(
	itemID int,
	locationID int,
	damageCount bigint,
	skipCount bigint,
	currentCount bigint,
	adjCount bigint,
	consumedCount bigint
);

INSERT INTO @InvItemLocCounts
(
	itemID,
	locationID,
	damageCount,
	skipCount,
	currentCount,
	adjCount,
	consumedCount
)
SELECT it.ivtInventoryItemID
	, itd.ivdInvLocationID
	, 0 -- damage
	, 0 -- skip
	, SUM(CONVERT(bigint, itd.ivdDelta)) -- current count
	, 0 -- adjustments
	, 0 -- consumed
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
	LEFT JOIN @Damages d ON (d.itemID = it.ivtInventoryItemID AND d.locationID = itd.ivdInvLocationID)
	LEFT JOIN @Skips s ON (s.itemID = it.ivtInventoryItemID AND s.locationID = itd.ivdInvLocationID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND ii.iiRetiredDate IS NULL
GROUP BY it.ivtInventoryItemID, itd.ivdInvLocationID

--Select *
--From @InvItemLocCounts

-- Update the damages column
UPDATE @InvItemLocCounts
SET damageCount = d.damageCount
FROM @InvItemLocCounts lc
	JOIN @Damages d ON (d.itemID = lc.itemID AND d.locationID = lc.locationID)

-- Update the skips column
UPDATE @InvItemLocCounts
SET skipCount = s.skipCount
FROM @InvItemLocCounts lc
	JOIN @Skips s ON (s.itemID = lc.itemID  AND s.locationID = lc.locationID)

-- Update the adjustments column
UPDATE @InvItemLocCounts
SET adjCount = a.adjCount
FROM @InvItemLocCounts lc
	JOIN @Adjustments a ON (a.itemID = lc.itemID AND a.locationID = lc.locationID)

-- Update the consumed column
UPDATE @InvItemLocCounts
SET consumedCount = c.consumedCount
FROM @InvItemLocCounts lc
	JOIN @Consumed c ON (c.itemID = lc.itemID AND c.locationID = lc.locationID)

-- DEBUG
--SELECT * FROM @InvItemLocCounts
-- END DEBUG

DECLARE @Results TABLE
(
    OperatorId  int,
    ManufId     int,
    VendorId    int,
    ProdItemId  int,
	ProdType    nvarchar(64),
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
	AdjCount	int,
    Damaged     bigint,
    Skipped     bigint,
	ConCount	bigint,
    CurrCount   bigint,
    Price       money,
    CostUnit     money
);

-- Insert the results into the table
INSERT INTO @Results
(  
	  OperatorId
	, ManufId
	, VendorId
	, ProdItemId
	, ProdType
	, ManufName, VendorName, ProdName
	, InvLoc
	, InvNbr, SerialNbr, RangeStart, RangeEnd
	, FirstIssued, LastIssued, Retired, TaxId     
	, CardCut, Up
	, StartCount, AdjCount, Damaged, Skipped, ConCount, CurrCount
	, Price, CostUnit
)
SELECT pdi.OperatorID
	, im.imInvManufacturerID
	, v.VendorID
	, pdi.ProductItemID
	, pt.ProductType
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
	, Case When lc.locationID = ii.iiStartLocationID Then ii.iiStartCount
		Else 0 End
	, lc.adjCount
	, lc.damageCount
	, lc.skipCount
	, lc.consumedCount
	, lc.CurrentCount
	, ii.iiPricePerItem
	, CASE WHEN ISNULL(ii.iiStartCount, 0) = 0 THEN 0
		ELSE (CONVERT(decimal, ii.iiCostPerItem) / CONVERT(decimal, ii.iiStartCount)) END
FROM @InvItemLocCounts lc
	JOIN InventoryItem ii ON (ii.iiInventoryItemID = lc.itemID)
	JOIN ProductItem pdi ON (pdi.ProductItemID = ii.iiProductItemID)
	JOIN ProductType pt on (pt.ProductTypeID = pdi.ProductTypeID)
	JOIN InvLocations il ON (il.ilInvLocationID = lc.LocationID)
	LEFT JOIN InvManufacturer im ON (im.imInvManufacturerID = ii.iiManufacturerID)
	LEFT JOIN Vendor v ON (v.VendorID = ii.iiVendorID)
	LEFT JOIN CardCuts cc ON (ii.iiCardCutID = cc.ccCardCutID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID IS NULL)
	AND il.ilInvLocationTypeID IN (1, 2)
	AND ii.iiRetiredDate IS NULL

-- DEBUG
--SELECT * FROM @Results
--SELECT * FROM InventoryItem
-- END DEBUG

-- Return resultset to the report
Select	ProdType,
		ProdName,
		InvLoc,
		SerialNbr,
		StartCount,
		AdjCount,
		Damaged,
		Skipped,
		ConCount,
		CurrCount
from @Results
order by OperatorId, ProdType, ProdName, SerialNbr;

Set Nocount Off


GO

