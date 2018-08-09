USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvPhysicalCount]    Script Date: 04/12/2012 08:17:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author: Brandon Hendrix
-- Description:	Returns the list inventory counts
-- by location and item
-- Note: Only Physical and Machine locations are
-- included
-- =============================================
alter PROCEDURE  [dbo].[spRptInvPhysicalCount] 
(
	@OperatorID		int,
	@InvLocationID  int,
	@ProductTypeID	int -- Actual product item id not product type
)
as
	
SET NOCOUNT ON;

-- Brandon Hendrix query returns a count for every item at every location
-- even if its 0 and has never been issued that item
-- left it in just in case this is what they really want.
--SELECT il2.ilInvLocationID AS LocationID
--	, il2.ilInvLocationName AS LocationName
--	, pdt.ProductType AS ProductType -- Product Type
--    , pdg.GroupName AS ProductGroup -- Product Group Name
--	, ii2.ItemName AS ProductItemName -- Product Item Name
--	, ii2.iiSerialNo AS SerialNumber -- Serial Number
--	, ii2.iiFormNumber AS FormNumber -- Form Number
--	, cc.ccOn AS PaperOn -- Paper On
--	, ii2.iiUp AS PaperUp -- Paper Up
--	, cc.ccCardCutName AS PaperCut -- Paper Cut
--	, SUM(CONVERT(bigint, ISNULL(it2.ivdDelta, 0))) AS CurrentCount -- Current Count
--FROM
--	(SELECT * FROM InventoryItem ii JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
--	WHERE (pdi.OperatorID = @OperatorID OR @OperatorID = 0)
--		AND (ii.iiProductItemID = @ProductTypeID OR @ProductTypeID = 0)
--		AND ii.iiRetiredDate IS NULL) AS ii2
--	CROSS JOIN (SELECT * FROM InvLocations il 
--				WHERE (il.ilInvLocationID = @InvLocationID OR @InvLocationID = 0)
--					AND il.ilInvLocationTypeID IN (1,2)) AS il2
--	LEFT JOIN (SELECT * FROM InvTransaction it JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)) AS it2 ON (it2.ivtInventoryItemID = ii2.iiInventoryItemID AND it2.ivdInvLocationID = il2.ilInvLocationID)
--	LEFT JOIN CardCuts cc ON (ii2.iiCardCutID = cc.ccCardCutID)
--	LEFT JOIN ProductGroup pdg ON (ii2.ProductGroupID = pdg.ProductGroupID)
--	LEFT JOIN ProductType pdt ON (ii2.ProductTypeID = pdt.ProductTypeID)
--GROUP BY il2.ilInvLocationID -- Location ID
--	, il2.ilInvLocationName -- Location Name
--	, pdt.ProductType -- Product Type
--    , pdg.GroupName -- Product Group Name
--	, ii2.ItemName -- Product Item Name
--	, ii2.iiSerialNo -- Serial Number
--	, ii2.iiFormNumber -- Form Number
--	, cc.ccOn -- Paper On
--	, ii2.iiUp -- Paper Up
--	, cc.ccCardCutName -- Paper Cut
--ORDER BY il2.ilInvLocationName
--	, pdt.ProductType
--	, ii2.ItemName;
---------------------------------------------------------------------------
--OLD(4.12.2012)
--SELECT itd.ivdInvLocationID AS LocationID -- Location ID
--	, il.ilInvLocationName AS LocationName -- Location Name
--	, pdt.ProductType AS ProductType -- Product Type
--    , pdg.GroupName AS ProductGroup -- Product Group Name
--	, pdi.ItemName AS ProductItemName -- Product Item Name
--	, ii.iiSerialNo AS SerialNumber -- Serial Number
--	, ii.iiFormNumber AS FormNumber -- Form Number
--	, cc.ccOn AS PaperOn -- Paper On
--	, ii.iiUp AS PaperUp -- Paper Up
--	, cc.ccCardCutName AS PaperCut -- Paper Cut
--	, SUM(CONVERT(bigint, ISNULL(itd.ivdDelta, 0))) AS CurrentCount -- Current Count
--FROM InvTransaction it
--	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
--	JOIN InvLocations il ON (itd.ivdInvLocationID = il.ilInvLocationID)
--	JOIN InventoryItem ii  ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
--	LEFT JOIN CardCuts cc ON (ii.iiCardCutID = cc.ccCardCutID)
--	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
--	LEFT JOIN ProductGroup pdg ON (pdi.ProductGroupID = pdg.ProductGroupID)
--	LEFT JOIN ProductType pdt ON (pdi.ProductTypeID = pdt.ProductTypeID)
--WHERE (pdi.OperatorID = @OperatorID OR @OperatorID = 0)
--	AND (itd.ivdInvLocationID = @InvLocationID OR @InvLocationID = 0)
--	AND (pdi.ProductItemID = @ProductTypeID OR @ProductTypeID = 0)
--	AND (il.ilInvLocationTypeID IN (1, 2)) -- (Physical, Machine)
--GROUP BY itd.ivdInvLocationID -- Location ID
--	, il.ilInvLocationName -- Location Name
--	, pdt.ProductType -- Product Type
--    , pdg.GroupName -- Product Group Name
--	, pdi.ItemName -- Product Item Name
--	, ii.iiSerialNo -- Serial Number
--	, ii.iiFormNumber -- Form Number
--	, cc.ccOn -- Paper On
--	, ii.iiUp -- Paper Up
--	, cc.ccCardCutName -- Paper Cut
--HAVING SUM(CONVERT(bigint, itd.ivdDelta)) > 0
--ORDER BY il.ilInvLocationName
--	, pdt.ProductType
--	, pdi.ItemName;
----------------------------------------------
--new 4.12.2012


--declare @OperatorID int
--declare @ProductTypeID int
--declare @InvLocationID int 

--set @OperatorID = 0
--set  @ProductTypeID = 0
--set @InvLocationID  = 0

select 
itd.ivdInvLocationID AS LocationID,
il.ilInvLocationName AS LocationName 
, pdt.ProductType AS ProductType 
, pdg.GroupName AS ProductGroup
, pdi.ItemName AS ProductItemName 
, ii.iiSerialNo AS SerialNumber 
, ii.iiFormNumber AS FormNumber 
, cc.ccOn AS PaperOn 
, ii.iiUp AS PaperUp
, cc.ccCardCutName AS PaperCut 
, SUM(CONVERT(bigint, ISNULL(itd.ivdDelta, 0))) AS CurrentCount 
 from 
InvTransactionDetail itd
JOIN InvLocations il ON itd.ivdInvLocationID = il.ilInvLocationID
join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
JOIN InventoryItem ii  ON it.ivtInventoryItemID = ii.iiInventoryItemID
LEFT JOIN CardCuts cc ON ii.iiCardCutID = cc.ccCardCutID
JOIN ProductItem pdi ON ii.iiProductItemID = pdi.ProductItemID
LEFT JOIN ProductGroup pdg ON pdi.ProductGroupID = pdg.ProductGroupID
LEFT JOIN ProductType pdt ON pdi.ProductTypeID = pdt.ProductTypeID
where il.ilInvLocationTypeID IN (1, 2)
	AND (pdi.ProductItemID = @ProductTypeID OR @ProductTypeID = 0)
 and (pdi.OperatorID = @OperatorID OR @OperatorID = 0)
 AND (itd.ivdInvLocationID = @InvLocationID OR @InvLocationID = 0)
 group by
 itd.ivdInvLocationID ,
il.ilInvLocationTypeID,
il.ilInvLocationName 
, ii.iiSerialNo 
, ii.iiFormNumber
, ii.iiUp 
, cc.ccOn 
, cc.ccCardCutName 
, pdi.ItemName 
, pdg.GroupName 
, pdt.ProductType 
,pdi.OperatorID
HAVING SUM(CONVERT(bigint, itd.ivdDelta)) > 0
ORDER BY il.ilInvLocationName
	, pdt.ProductType
	, pdi.ItemName;
	
SET NOCOUNT OFF;

GO


