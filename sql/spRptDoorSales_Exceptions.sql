USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Exceptions]    Script Date: 05/23/2013 12:35:25 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales_Exceptions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales_Exceptions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Exceptions]    Script Date: 05/23/2013 12:35:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptDoorSales_Exceptions] 
-- =============================================
-- Author:		Louis J. Landerman
-- Description:	<>
-- 2011.08.05 bjs: US1902 add prod group param
-- 2011.11.30 bjs: DE8879 invalid voids
-- 2011.11.08 bsb: DE9766 void amount invalid
-- 2011.12.16 jkn: DE9800 transfer receipt totals
--                  when transferred receipts are voided.
-- 2012.02.15 jkn: DE10025 account for device fees when transferring units
-- 2013.05.23 tmp: US2651 add serial number columns
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int

AS
	
SET NOCOUNT ON

-- FIX US1902
-- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...
--declare @groupName nvarchar(64); set @groupName = '';
--select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;

-- FIX: DE7330 - Transfers not listed and void data is wrong.
DECLARE @ResultsTable TABLE
(
	RegisterReceiptID1 INT,
	ReceiptNumber1 INT,
	TimeStamp1 DATETIME,
	PackNumber INT,
	UnitNumber1 INT,
	ReceiptTotal1 MONEY,
	RegisterReceiptID2 INT,
	ReceiptNumber2 INT,
	TimeStamp2 DATETIME,
	TransactionType NVARCHAR(64),
	UnitNumber2 INT,
	ReceiptTotal2 MONEY,
	GroupName nvarchar(64),
	DiscountAmt money,
	SalesTaxAmt money,
	DeviceFeeAmnt money,
	SerialNumber1 NVARCHAR(15),
	SerialNumber2 NVARCHAR(15)
);

-- Gather all of the receipts that were voided
INSERT INTO @ResultsTable
(
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	ReceiptTotal1,
	SerialNumber1
)
SELECT	rr.RegisterReceiptID,
		rr.TransactionNumber,
		rr.DTStamp,
		rr.PackNumber,
		rr.UnitNumber,
		sum(rd.Quantity * rdi.Qty * rdi.Price ) + isnull(rr.DeviceFee, 0), -- DE8879
		rr.UnitSerialNumber
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID IN (1, 3) 
	AND rr.OperatorID = @OperatorID
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND EXISTS (SELECT 1 FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NOT NULL)
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rr.DeviceFee, rr.UnitSerialNumber;

-- Update the voided receipts with the void times and transaction numbers
UPDATE @ResultsTable 
SET RegisterReceiptID2 = rr.RegisterReceiptID,
	ReceiptNumber2 = rr.TransactionNumber,
	TimeStamp2 = rr.DTStamp,
	TransactionType = 'Void',
	UnitNumber2 = UnitNumber1,
	ReceiptTotal2 = -1 * ReceiptTotal1,
	SerialNumber2 = SerialNumber1
FROM @ResultsTable rt
	JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)
where rr.TransactionTypeId = 2 --DE9800 make sure to only include voided transactions

-- Gather all of the receipts that were transferred.
INSERT INTO @ResultsTable
(
    RegisterReceiptID1
   ,ReceiptNumber1
   ,TimeStamp1
   ,PackNumber
   ,UnitNumber1
   ,ReceiptTotal1
   ,TransactionType
   ,SerialNumber1
)
SELECT	rr.RegisterReceiptID
       ,rr.TransactionNumber
       ,rr.DTStamp
       ,rr.PackNumber
       ,rr.UnitNumber
       ,sum(rd.Quantity * rdi.Qty * rdi.Price) + isnull(rr.DeviceFee, 0)-- DE9800/ DE10025
       ,'Transfer'
       ,rr.UnitSerialNumber
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID IN (1, 3)
	AND rr.OperatorID = @OperatorID
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND EXISTS (SELECT 1 FROM RegisterReceipt WHERE OriginalReceiptID = rr.RegisterReceiptID AND TransactionTypeID = 14)
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rr.DeviceFee, rr.UnitSerialNumber;

-- Update transfers with transfer details.
UPDATE @ResultsTable 
SET RegisterReceiptID2 = rr.RegisterReceiptID,
	ReceiptNumber2 = rr.TransactionNumber,
	TimeStamp2 = rr.DTStamp,
	UnitNumber2 = rr.UnitNumber,
	SerialNumber2 = rr.UnitSerialNumber,
    ReceiptTotal2 = 0 -- DE9800 Transfers are a 0 dollar transaction
FROM @ResultsTable rt
	JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)
WHERE rt.TransactionType = 'Transfer'
And rr.TransactionTypeID = 14	-------------- Join on transfer transactions only, if a unit is sold, transferred, voided the result returned the voided transaction info

-- Find all subsequent transfers.
DECLARE @CurrentTransferID INT
DECLARE @OriginalPackNumber INT
DECLARE @OriginalTotal MONEY

DECLARE TransferCursor CURSOR FOR
SELECT RegisterReceiptID2, PackNumber, ReceiptTotal1
FROM @ResultsTable
WHERE TransactionType = 'Transfer'

-- The algorithm below depends on fact that, after a cursor is opened, any rows
-- inserted will not be read by the cursor.
OPEN TransferCursor

FETCH NEXT FROM TransferCursor INTO @CurrentTransferID, @OriginalPackNumber, @OriginalTotal
WHILE @@FETCH_STATUS = 0
BEGIN
	-- Does the current transfer have another transfer after it?
	WHILE EXISTS(SELECT 1 FROM RegisterReceipt WHERE OriginalReceiptID = @CurrentTransferID AND TransactionTypeID = 14)
	BEGIN
		-- We did find another transfer, so add it to the results.
		INSERT INTO @ResultsTable
		(
			RegisterReceiptID1,
			ReceiptNumber1,
			TimeStamp1,
			PackNumber,
			UnitNumber1,
			SerialNumber1,
			ReceiptTotal1,
			RegisterReceiptID2,
			ReceiptNumber2,
			TimeStamp2,
			TransactionType,
			UnitNumber2,
			SerialNumber2,
			ReceiptTotal2
		)
		SELECT
			@CurrentTransferID,
			rr.TransactionNumber,
			rr.DTStamp,
			@OriginalPackNumber,
			rr.UnitNumber,
			rr.UnitSerialNumber,
			@OriginalTotal,
			transrr.RegisterReceiptID,
			transrr.TransactionNumber,
			transrr.DTStamp,
			'Transfer',
			transrr.UnitNumber,
			transrr.UnitSerialNumber,
            0 --DE9800 transfers are 0 dollar transactions
		FROM RegisterReceipt rr
			JOIN RegisterReceipt transrr ON (rr.RegisterReceiptID = transrr.OriginalReceiptID)
			left join RegisterDetail rd on rd.RegisterReceiptID = transrr.RegisterReceiptID
			left join RegisterDetailItems rdi on rdi.RegisterDetailID = rd.RegisterDetailID
		WHERE rr.RegisterReceiptID = @CurrentTransferID
			AND rr.TransactionTypeID = 14
			AND transrr.TransactionTypeID = 14
		SELECT @CurrentTransferID = RegisterReceiptID 
		FROM RegisterReceipt 
		WHERE OriginalReceiptID = @CurrentTransferID AND TransactionTypeID = 14;
	END

	FETCH NEXT FROM TransferCursor INTO @CurrentTransferID, @OriginalPackNumber, @OriginalTotal
END

CLOSE TransferCursor
DEALLOCATE TransferCursor
-- END: DE7330

--------------------------------------------------
--DE9766
--DE9800 Adjust for the discounts and sales tax values
update 	t1 
	set	t1.DiscountAmt = t2.TotalDiscount,
	    t1.SalesTaxAmt = t2.TotalSalesTaxAmount,
        t1.ReceiptTotal1 = isnull(t1.ReceiptTotal1,0) - isnull(t2.TotalDiscount,0) + isnull(t2.TotalSalesTaxAmount,0),
        t1.ReceiptTotal2 = case when t1.TransactionType = 'Transfer'
                                then 0 
                                else isnull(t1.ReceiptTotal2,0) + isnull(t2.TotalDiscount,0) - isnull(t2.TotalSalesTaxAmount,0) end
from	@ResultsTable t1 inner join
	(
		select 	RegisterReceiptID, sum(DiscountAmount * Quantity *(-1)) as TotalDiscount,
		        SUM(SalesTaxAmt * Quantity) as TotalSalesTaxAmount
		from	RegisterDetail
		group by RegisterReceiptID
	) as t2
	on	t1.RegisterReceiptID1	= t2.RegisterReceiptID
---------------------------------------------------

SELECT 	
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	SerialNumber1,
	ReceiptTotal1,
	ReceiptNumber2,
	TimeStamp2,
	TransactionType,
	UnitNumber2,
	SerialNumber2,
	ReceiptTotal2
FROM @ResultsTable
group by 
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	SerialNumber1,
	ReceiptNumber2,
	TimeStamp2,
	TransactionType,
	UnitNumber2,
	SerialNumber2,
    ReceiptTotal1,
    ReceiptTotal2;

SET NOCOUNT OFF









GO

