USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_InvTransfers]    Script Date: 05/07/2014 14:46:50 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryTransaction_InvTransfers]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryTransaction_InvTransfers]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_InvTransfers]    Script Date: 05/07/2014 14:46:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------
-- 2014.05.07 tmp: US3367 Add filter by Gaming Date or Transaction Date
---------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spRptInventoryTransaction_InvTransfers] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@StaffID	as int	
AS
    SET NOCOUNT ON;

    -- setup start and end dates.
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 1, datediff(day, 0, @EndDate));

    declare @Results table
	(
		txID int,
		txMID int,
		txTimestamp smalldatetime,
		txGamingDate smalldatetime,
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff nvarchar(260),
		txQty int,
		txSerialNo nvarchar(260),
		txFromLocation nvarchar(260),
		txToLocation nvarchar(260)		
	);
	
    --
    -- Populate all transactions within the time span passed that are issues
    --	
    insert into @Results
	(
		txID,
		txMID,
		txTimestamp,
		txGamingDate,
		txTransTypeID,
		txTransTypeName,
		txStaff,
		txQty,
		txSerialNo,
		txFromLocation,
		txToLocation		
	)
    select
		ivt.ivtInvTransactionID,
		ivt.ivtMasterTransactionID,
		ivt.ivtInvTransactionDate,
		ivt.ivtGamingDate,
		ivt.ivtTransactionTypeID,
		tt.TransactionType,
		(s.FirstName + ' ' + s.LastName),
		isnull((SELECT TOP 1 itd.ivdDelta
				 FROM InvTransactionDetail itd
				 WHERE itd.ivdInvTransactionID = ivt.ivtInvTransactionID
				 ORDER BY ivdDelta DESC), 0),
		ii.iiSerialNo,
		isnull((SELECT TOP 1 il.ilInvLocationName
						  FROM InvLocations il
						  JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						  WHERE itd.ivdInvTransactionID = ivt.ivtInvTransactionID
						  ORDER BY ivdDelta ASC), ''),
		isnull((SELECT TOP 1 il.ilInvLocationName
						  FROM InvLocations il
						  JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						  WHERE itd.ivdInvTransactionID = ivt.ivtInvTransactionID
						  ORDER BY ivdDelta DESC), '')
    from Operator o -- DE7586
        join ProductItem pi on pi.OperatorID = o.OperatorID -- DE7586
        join InventoryItem i on i.iiProductItemID = pi.ProductItemID -- DE7586
        join InvTransaction ivt on ivt.ivtInventoryItemID = i.iiInventoryItemID -- DE7586
        join TransactionType tt on (tt.TransactionTypeID = ivt.ivtTransactionTypeID)
        join InventoryItem ii on (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
        join Staff s on (s.StaffID = ivt.ivtStaffID)
    where ((ivt.ivtGamingDate >= @StartDate
        and ivt.ivtGamingDate < @EndDate)
        or	(ivt.ivtInvTransactionDate >= @StartDate and ivt.ivtInvTransactionDate <= @EndDate))	-- US3367
        and ivt.ivtTransactionTypeID = 32 -- US1639 INVENTORY TRANSFER
        and (@OperatorID = 0 or o.OperatorID = @OperatorID) -- DE7586
        and (@StaffID = 0 or StaffID = @StaffID);


    --
    -- Select our final result set
    -- 	
    select * from @Results;





















GO

