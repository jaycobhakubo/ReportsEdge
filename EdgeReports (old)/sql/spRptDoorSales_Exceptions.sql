USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Exceptions]    Script Date: 12/08/2011 09:03:21 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales_Exceptions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales_Exceptions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Exceptions]    Script Date: 12/08/2011 09:03:21 ******/
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
declare @groupName nvarchar(64); set @groupName = '';
select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;


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
	GroupName nvarchar(64)
	, DiscountAmt money
	, SalesTaxAmt money
	
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
	GroupName
)
SELECT	rr.RegisterReceiptID,
		rr.TransactionNumber,
		rr.DTStamp,
		rr.PackNumber,
		rr.UnitNumber,
		--SUM(rd.Quantity * rd.PackagePrice + ISNULL(rd.DiscountAmount, 0) + ISNULL(rd.SalesTaxAmt, 0)),
		sum(rd.Quantity * rdi.Qty * rdi.Price ) -- DE8879
		,rdi.GroupName
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
	and (@ProductGroupID = 0 or @groupName = rdi.GroupName)
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rdi.GroupName;


-- Add sales tax and discount.  Do not sum these values for each detail line item as it makes the receipt total too big.
update @ResultsTable 
set DiscountAmt = ISNULL(rd.DiscountAmount,0),
    SalesTaxAmt = ISNULL(rd.SalesTaxAmt,0)
FROM @ResultsTable rt
join RegisterDetail rd on rt.RegisterReceiptID1 = rd.RegisterReceiptID;
--------------------------------------------------
--DE9766
update 	t1 
	set	t1.DiscountAmt = t2.TotalDiscount,
	    t1.SalesTaxAmt = t2.TotalSalesTaxAmount
from	@ResultsTable t1 inner join
	(
		select 	RegisterReceiptID, sum(DiscountAmount * Quantity *(-1)) as TotalDiscount,
		        SUM(SalesTaxAmt * Quantity) as TotalSalesTaxAmount
		from	RegisterDetail
		group by RegisterReceiptID
	) as t2
	on	t1.RegisterReceiptID1	= t2.RegisterReceiptID

---------------------------------------------------


-- Update the voided receipts with the void times and transaction numbers
UPDATE @ResultsTable 
SET RegisterReceiptID2 = rr.RegisterReceiptID,
	ReceiptNumber2 = rr.TransactionNumber,
	TimeStamp2 = rr.DTStamp,
	TransactionType = 'Void',
	UnitNumber2 = UnitNumber1,
	ReceiptTotal2 = -1 * ReceiptTotal1
FROM @ResultsTable rt
	JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)

-- Gather all of the receipts that were transferred.
INSERT INTO @ResultsTable
(
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	ReceiptTotal1,
	TransactionType,
	GroupName
)
SELECT	rr.RegisterReceiptID,
		rr.TransactionNumber,
		rr.DTStamp,
		rr.PackNumber,
		rr.UnitNumber,
		SUM(rd.Quantity * rd.PackagePrice + ISNULL(rd.DiscountAmount, 0) + ISNULL(rd.SalesTaxAmt, 0)),
		'Transfer',
		rdi.GroupName
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
	and (@ProductGroupID = 0 or @groupName = rdi.GroupName)
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rdi.GroupName;



-- Update transfers with transfer details.
UPDATE @ResultsTable 
SET RegisterReceiptID2 = rr.RegisterReceiptID,
	ReceiptNumber2 = rr.TransactionNumber,
	TimeStamp2 = rr.DTStamp,
	UnitNumber2 = rr.UnitNumber,
	ReceiptTotal2 = ReceiptTotal1
FROM @ResultsTable rt
	JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)
WHERE rt.TransactionType = 'Transfer'

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
			ReceiptTotal1,
			RegisterReceiptID2,
			ReceiptNumber2,
			TimeStamp2,
			TransactionType,
			UnitNumber2,
			ReceiptTotal2,
			GroupName
		)
		SELECT
			@CurrentTransferID,
			rr.TransactionNumber,
			rr.DTStamp,
			@OriginalPackNumber,
			rr.UnitNumber,
			@OriginalTotal,
			transrr.RegisterReceiptID,
			transrr.TransactionNumber,
			transrr.DTStamp,
			'Transfer',
			transrr.UnitNumber,
			@OriginalTotal,
			GroupName
		FROM RegisterReceipt rr
			JOIN RegisterReceipt transrr ON (rr.RegisterReceiptID = transrr.OriginalReceiptID)
			join RegisterDetail rd on rd.RegisterReceiptID = transrr.RegisterReceiptID
			join RegisterDetailItems rdi on rdi.RegisterDetailID = rd.RegisterDetailID
		WHERE rr.RegisterReceiptID = @CurrentTransferID
			AND rr.TransactionTypeID = 14
			AND transrr.TransactionTypeID = 14
			and (@ProductGroupID = 0 or @groupName = rdi.GroupName)
		SELECT @CurrentTransferID = RegisterReceiptID 
		FROM RegisterReceipt 
		WHERE OriginalReceiptID = @CurrentTransferID AND TransactionTypeID = 14;
	END

	FETCH NEXT FROM TransferCursor INTO @CurrentTransferID, @OriginalPackNumber, @OriginalTotal
END

CLOSE TransferCursor
DEALLOCATE TransferCursor
-- END: DE7330


-- DE8879: suppress detail items, show only receipt total
DECLARE @Results TABLE
(
	RegisterReceiptID1 INT,
	ReceiptNumber1 INT,
	TimeStamp1 DATETIME,
	PackNumber INT,
	UnitNumber1 INT,
	ReceiptTotal1 MONEY,
	--RegisterReceiptID2 INT,
	ReceiptNumber2 INT,
	TimeStamp2 DATETIME,
	TransactionType NVARCHAR(64),
	UnitNumber2 INT,
	ReceiptTotal2 MONEY
);

insert into @Results
SELECT 	
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	sum(ReceiptTotal1),
	ReceiptNumber2,
	TimeStamp2,
	TransactionType,
	UnitNumber2,
	sum(ReceiptTotal2)
FROM @ResultsTable
group by 
	RegisterReceiptID1,
	ReceiptNumber1,
	TimeStamp1,
	PackNumber,
	UnitNumber1,
	ReceiptNumber2,
	TimeStamp2,
	TransactionType,
	UnitNumber2;

--select * from @Results
--select * from @ResultsTable
--select * from @Results;

declare @Amounts table
(
	RegisterReceiptID1 INT,
	DiscountAmt MONEY,
	SalesTaxAmt MONEY   
);

insert into @Amounts
select distinct(RegisterReceiptID1), isnull(DiscountAmt,0), isnull(SalesTaxAmt, 0)
from @ResultsTable;

--select * from @Amounts;
-- DEBUG
--select * from @ResultsTable
-- select * from @Results;
--return;

declare @tot1 money;
declare @tot2 money;
declare @disc money;
declare @tax money;
declare @id int;

declare TOTALS cursor local fast_forward for
select RegisterReceiptID1, isnull(ReceiptTotal1,0), isnull(ReceiptTotal2,0) from @Results;

open TOTALS;
fetch next from TOTALS into @id, @tot1, @tot2;

while @@fetch_status = 0
begin
    --select @disc = isnull(DiscountAmt,0), @tax = isnull(SalesTaxAmt,0) from @ResultsTable where RegisterReceiptID1 = @id;
    select @disc = isnull(DiscountAmt,0), @tax = isnull(SalesTaxAmt, 0)
    from @Amounts
    where RegisterReceiptID1 = @id;

    print '';
    print @id;
    print @tot1;
    print @tot2;
    print @disc;
    print @tax;
        
    update @Results 
        set ReceiptTotal1 = @tot1 - @disc + @tax,
            ReceiptTotal2 = @tot2 + @disc - @tax 
    where RegisterReceiptID1 = @id;
    
    fetch next from TOTALS into @id, @tot1, @tot2;
end;

-- Finally return our set!
select * from @Results;

SET NOCOUNT OFF







GO


