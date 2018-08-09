USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_Receive]    Script Date: 05/22/2012 13:52:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryTransaction_Receive]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryTransaction_Receive]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_Receive]    Script Date: 05/22/2012 13:52:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[spRptInventoryTransaction_Receive] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@StaffID	as int	
AS
SET NOCOUNT ON

SET @EndDate = DateAdd(day, 1, @EndDate)

declare @TmpIndex int,
		@locTypeID int

CREATE TABLE #TempTble
	(
		txID INT,
		txMID int,
		txTimestamp SMALLDATETIME,
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff nvarchar(260),
		txQty int,
		txSerialNo nvarchar(260),
		txToLocation nvarchar(260),
		txInvoice nvarchar(30),
		txCostPer money,
		txPricePer money,
		txFormName nvarchar(30),
		txFormNumber nvarchar(30),
		txHoldPerc money,
		txProductType int
	)
	
--
-- Populate all transactions within the time span passed that are issues
--	
INSERT INTO #TempTble
	(
		txID,
		txMID,
		txTimestamp,
		txTransTypeID,
		txTransTypeName,
		txStaff,
		txQty,
		txSerialNo,
		txToLocation,
		txInvoice,
		txCostPer,
		txPricePer,
		txFormName,
		txFormNumber,
		txHoldPerc,
		txProductType	
	)
SELECT 
		ivt.ivtInvTransactionID,
		ivt.ivtMasterTransactionID ,
		ivt.ivtInvTransactionDate,
		ivt.ivtTransactionTypeID,
		tt.TransactionType,
		(s.FirstName + ' ' + s.LastName),
		0,
		ii.iiSerialNo,
		'',
		ivt.ivtInvoiceNo,
		ivt.ivtCostPerItem,
		ivt.ivtPrice,
		ii.iiTabName,
		ii.iiFormNumber,
		ii.iiHoldPercentage,
		p.ProductTypeID
FROM Operator o																-- DE7586
join ProductItem pi on pi.OperatorID = o.OperatorID							-- DE7586
join InventoryItem i on i.iiProductItemID = pi.ProductItemID				-- DE7586
join InvTransaction ivt on ivt.ivtInventoryItemID = i.iiInventoryItemID		-- DE7586
JOIN TransactionType tt ON (tt.TransactionTypeID = ivt.ivtTransactionTypeID)
LEFT JOIN Staff s ON (s.StaffID = ivt.ivtStaffID) -- Long term, shouldn't need to left join (should always be a matching staff)
JOIN InventoryItem ii ON (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
JOIN ProductItem p ON (p.ProductItemID = ii.iiProductItemID)
WHERE 
(o.OperatorID = @OperatorID or @OperatorID = 0) AND							-- DE7586
ivt.ivtTransactionTypeID = 28 -- Moves
AND ivt.ivtInvTransactionDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS SMALLDATETIME)
AND ivt.ivtInvTransactionDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS SMALLDATETIME)
and (@StaffID = 0 or ivtStaffID = @StaffID);

--
-- Update the From and To locations for each record in the temp table
--
DECLARE TempTableCursor CURSOR FOR
SELECT txID FROM #TempTble

OPEN TempTableCursor

FETCH NEXT FROM TempTableCursor INTO @TmpIndex
WHILE @@FETCH_STATUS = 0
BEGIN
	--
	-- To Location
	--
	UPDATE #TempTble
	SET txToLocation = (SELECT TOP 1 il.ilInvLocationName
						FROM InvLocations il
						JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						WHERE itd.ivdInvTransactionID = @TmpIndex
						ORDER BY ivdDelta DESC)
	WHERE txID = @TmpIndex
	
	--
	-- Amount of issue
	--
	UPDATE #TempTble
	SET txQty = (SELECT TOP 1 itd.ivdDelta
				 FROM InvTransactionDetail itd
				 WHERE itd.ivdInvTransactionID = @TmpIndex
				 ORDER BY ivdDelta DESC)
	WHERE txID = @TmpIndex

	FETCH NEXT FROM TempTableCursor INTO @TmpIndex
END

CLOSE TempTableCursor
DEALLOCATE TempTableCursor
	

	declare @TmpIndex2 int,
		@locTypeID2 int

CREATE TABLE #TempTble2
	(
		txID INT,
		txTimestamp SMALLDATETIME,
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff nvarchar(260),
		txQty int,
		txSerialNo nvarchar(260),
		txFromLocation nvarchar(260),
		txToLocation nvarchar(260)		
	)
	
--
-- Populate all transactions within the time span passed that are issues
--	
INSERT INTO #TempTble2
	(
		txID, 
		txTimestamp,
		txTransTypeID,
		txTransTypeName,
		txStaff,
		txQty,
		txSerialNo,
		txFromLocation,
		txToLocation		
	)
SELECT 
		ivt.ivtInvTransactionID,
		ivt.ivtInvTransactionDate,
		ivt.ivtTransactionTypeID,
		tt.TransactionType,
		(s.FirstName + ' ' + s.LastName),
		0,
		ii.iiSerialNo,
		'',
		''
FROM Operator o																-- DE7586
join ProductItem pi on pi.OperatorID = o.OperatorID							-- DE7586
join InventoryItem i on i.iiProductItemID = pi.ProductItemID				-- DE7586
join InvTransaction ivt on ivt.ivtInventoryItemID = i.iiInventoryItemID		-- DE7586
JOIN TransactionType tt ON (tt.TransactionTypeID = ivt.ivtTransactionTypeID)
JOIN InventoryItem ii ON (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
JOIN Staff s ON (s.StaffID = ivt.ivtStaffID)
WHERE 
(o.OperatorID = @OperatorID or @OperatorID = 0) AND							-- DE7586
ivt.ivtTransactionTypeID = 25 -- ISSUE
--AND ivt.ivtInvTransactionDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS SMALLDATETIME)
--AND ivt.ivtInvTransactionDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS SMALLDATETIME)
and (@StaffID = 0 or ivtStaffID = @StaffID);

--
-- Update the From and To locations for each record in the temp table
--
DECLARE TempTableCursor CURSOR FOR
SELECT txID FROM #TempTble2

OPEN TempTableCursor

FETCH NEXT FROM TempTableCursor INTO @TmpIndex2
WHILE @@FETCH_STATUS = 0
BEGIN
	--
	-- From Location
	--
	UPDATE #TempTble2
	SET txFromLocation = (SELECT TOP 1 il.ilInvLocationName
						  FROM InvLocations il
						  JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						  WHERE itd.ivdInvTransactionID = @TmpIndex
						  ORDER BY ivdDelta ASC)
	WHERE txID = @TmpIndex2
	
	--
	-- To Location
	--
	UPDATE #TempTble2
	SET txToLocation = (SELECT TOP 1 il.ilInvLocationName
						  FROM InvLocations il
						  JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						  WHERE itd.ivdInvTransactionID = @TmpIndex
						  ORDER BY ivdDelta DESC)
	WHERE txID = @TmpIndex2
	
	--
	-- Amount of issue
	--
	UPDATE #TempTble2
	SET txQty = (SELECT TOP 1 itd.ivdDelta
				 FROM InvTransactionDetail itd
				 WHERE itd.ivdInvTransactionID = @TmpIndex
				 ORDER BY ivdDelta DESC)
	WHERE txID = @TmpIndex2

	FETCH NEXT FROM TempTableCursor INTO @TmpIndex2;
END

CLOSE TempTableCursor;
DEALLOCATE TempTableCursor;
	
--
-- Select our final result set
	
--
-- Select our final result set
-- 	
SELECT a.* FROM #TempTble a
join (
SELECT txID FROM #TempTble2 where 
 txTimestamp >= CAST(CONVERT(varchar(14), @StartDate, 101) AS SMALLDATETIME)
	AND txTimestamp <= CAST(CONVERT(varchar(14), @EndDate, 101) AS SMALLDATETIME)) b
	on a.txMID = b.txID 
	
	
DROP TABLE #TempTble
drop table #TempTble2 

--SET NOCOUNT OFF







GO


