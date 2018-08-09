USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDailyInventoryMovement]    Script Date: 05/07/2014 14:01:36 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDailyInventoryMovement]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDailyInventoryMovement]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDailyInventoryMovement]    Script Date: 05/07/2014 14:01:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptDailyInventoryMovement] 
-- =============================================
-- Author:		Louis J. Landerman
-- Description:	
-- 02/09/2011 BJS: DE7443 correlated subquery fails but transaction still valid.
-- 2012.06.13 bdh: DE10397 only show transactions for given date range.
-- 2014.05.07 tmp: US3366 Filter by Gaming Date or Transaction Date.
-- =============================================
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME
AS
	
SET NOCOUNT ON

DECLARE @ResultsTable TABLE
(
	GamingDate DATETIME,				-- The GamingDate of the transaction
	ProductName NVARCHAR(64),			-- The name of the product that was moved
	SerialNumber NVARCHAR(30),			-- The serial number that was moved
	TargetLocationName NVARCHAR(64),	-- The main location to be reported on (Most transactions will have 2 records with each side as the target)
	OtherLocationName NVARCHAR(64),		-- The other location in the move
	TransactionType INT,				-- The type of inventory transaction
	InvChangeToTarget INT,				-- The amount the target inventory changed due to this
	GamingSession INT,					-- What session was this transaction tied to?	
	TransTimestamp DATETIME,			-- The time of this transaction	
	StaffName NVARCHAR(130)				-- The staff that did the transaction	
);

DECLARE @TransID INT

-- Create a list of all inventory
-- transactions for the date we are interested in
DECLARE @InventoryTransactions TABLE
(
	InventoryTransactionID INT
);
INSERT INTO @InventoryTransactions
SELECT ivtInvTransactionID
FROM InvTransaction ivt
	JOIN InventoryItem ivi ON (ivt.ivtInventoryItemID = ivi.iiInventoryItemID)
	JOIN ProductItem pri ON (pri.ProductItemID = ivi.iiProductItemID)
WHERE ((ivt.ivtGamingDate >= @StartDate AND ivt.ivtGamingDate <= @EndDate) 
	or	(cast(ivt.ivtInvTransactionDate as Date) >= @StartDate and	-- US3366
		cast(ivt.ivtInvTransactionDate as Date) <= @EndDate))		-- US3366
	AND pri.OperatorID = @OperatorID
ORDER BY ivtInvTransactionID

-- Loop through each transaction and add a record for each (to) and (from)
Declare TransactionCursor CURSOR FOR select InventoryTransactionID from @InventoryTransactions
OPEN TransactionCursor
FETCH NEXT FROM TransactionCursor INTO @TransID
WHILE @@FETCH_STATUS = 0
BEGIN

    -- FIX DE7443: correlated subquery fails but transaction is still accurate
    begin try
	    -- Add the positive record
	    INSERT INTO @ResultsTable
	    (
		    GamingDate,
		    ProductName,
		    SerialNumber,
		    TargetLocationName,
		    OtherLocationName,
		    TransactionType,
		    InvChangeToTarget,
		    GamingSession,
		    TransTimestamp,
			StaffName
	    )
	    SELECT	ivt.ivtGamingDate,
			    pri.ItemName,
			    ii.iiSerialNo,
			    (SELECT il2.ilInvLocationName 
			     FROM InvLocations il2
				    JOIN InvTransactionDetail itd2 ON (itd2.ivdInvLocationID = il2.ilInvLocationID)
				    JOIN InvTransaction it2 ON (it2.ivtInvTransactionID = itd2.ivdInvTransactionID)
			     WHERE it2.ivtInvTransactionID = ivt.ivtInvTransactionID
					AND itd2.ivdDelta < 0),
			    (SELECT il3.ilInvLocationName 
			     FROM InvLocations il3
				    JOIN InvTransactionDetail itd3 ON (itd3.ivdInvLocationID = il3.ilInvLocationID)
				    JOIN InvTransaction it3 ON (it3.ivtInvTransactionID = itd3.ivdInvTransactionID)
			     WHERE it3.ivtInvTransactionID = ivt.ivtInvTransactionID
					AND itd3.ivdDelta > 0),
			    ivt.ivtTransactionTypeID,
			    (SELECT itd4.ivdDelta 
			     FROM InvLocations il4
				    JOIN InvTransactionDetail itd4 ON (itd4.ivdInvLocationID = il4.ilInvLocationID)
				    JOIN InvTransaction it4 ON (it4.ivtInvTransactionID = itd4.ivdInvTransactionID)
			     WHERE it4.ivtInvTransactionID = ivt.ivtInvTransactionID
					AND itd4.ivdDelta < 0),
			    ivt.ivtGamingSession,
			    ivt.ivtInvTransactionDate,
				LTRIM(RTRIM(s.FirstName + ' ' + s.LastName))
	    FROM InvTransaction ivt
		    JOIN InventoryItem ii ON (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
		    JOIN ProductItem pri ON (pri.ProductItemID = ii.iiProductItemID)
			LEFT JOIN Staff s ON (ivt.ivtStaffId = s.StaffId)
	    WHERE @TransID = ivt.ivtInvTransactionID
    end try
    begin catch
        print 'Failed to add positive record, continuing...';    
    end catch;
    
    begin try
	    -- Add the negative record
	    INSERT INTO @ResultsTable
	    (
		    GamingDate,
		    ProductName,
		    SerialNumber,
		    TargetLocationName,
		    OtherLocationName,
		    TransactionType,
		    InvChangeToTarget,
		    GamingSession,
		    TransTimestamp,
			StaffName
	    )
	    SELECT	ivt.ivtGamingDate,
			    pri.ItemName,
			    ii.iiSerialNo,
			    (SELECT il2.ilInvLocationName 
			     FROM InvLocations il2
				    JOIN InvTransactionDetail itd2 ON (itd2.ivdInvLocationID = il2.ilInvLocationID)
				    JOIN InvTransaction it2 ON (it2.ivtInvTransactionID = itd2.ivdInvTransactionID)
			     WHERE it2.ivtInvTransactionID = ivt.ivtInvTransactionID
					AND itd2.ivdDelta > 0),
			    (SELECT il3.ilInvLocationName 
			     FROM InvLocations il3
				    JOIN InvTransactionDetail itd3 ON (itd3.ivdInvLocationID = il3.ilInvLocationID)
				    JOIN InvTransaction it3 ON (it3.ivtInvTransactionID = itd3.ivdInvTransactionID)
			     WHERE it3.ivtInvTransactionID = ivt.ivtInvTransactionID
			     AND itd3.ivdDelta < 0),
			    ivt.ivtTransactionTypeID,
			    (SELECT itd4.ivdDelta 
			     FROM InvLocations il4
				    JOIN InvTransactionDetail itd4 ON (itd4.ivdInvLocationID = il4.ilInvLocationID)
				    JOIN InvTransaction it4 ON (it4.ivtInvTransactionID = itd4.ivdInvTransactionID)
			     WHERE it4.ivtInvTransactionID = ivt.ivtInvTransactionID
					AND itd4.ivdDelta > 0),
			    ivt.ivtGamingSession,
			    ivt.ivtInvTransactionDate,
				LTRIM(RTRIM(s.FirstName + ' ' + s.LastName))
	    FROM InvTransaction ivt
		    JOIN InventoryItem ii ON (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
		    JOIN ProductItem pri ON (pri.ProductItemID = ii.iiProductItemID)
			LEFT JOIN Staff s ON (ivt.ivtStaffId = s.StaffId)
	    WHERE @TransID = ivt.ivtInvTransactionID
    end try
    begin catch
        print 'Failed to add NEGATIVE, continuing...';    
    end catch;
    -- END DE7443
    
	FETCH NEXT FROM TransactionCursor INTO @TransID
END
CLOSE TransactionCursor
DEALLOCATE TransactionCursor

-- remove results where the target is null
DELETE FROM @ResultsTable
WHERE TargetLocationName IS NULL 
	OR InvChangeToTarget IS NULL

SELECT	GamingDate,
		ProductName,
		SerialNumber,
		TargetLocationName,
		ISNULL(OtherLocationName, '') AS OtherLocationName,
		TransactionType,
		InvChangeToTarget,
		ISNULL(GamingSession, 0) AS GamingSession,
		TransTimestamp,
		StaffName
FROM @ResultsTable
ORDER BY ProductName, SerialNumber, GamingDate, TargetLocationName, TransTimestamp

SET NOCOUNT OFF
















GO

