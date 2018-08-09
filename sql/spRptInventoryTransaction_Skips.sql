USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_Skips]    Script Date: 05/07/2014 14:48:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryTransaction_Skips]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryTransaction_Skips]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction_Skips]    Script Date: 05/07/2014 14:48:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptInventoryTransaction_Skips] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@StaffID	as int	
AS
    set nocount on;

    -- setup start and end dates.
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 1, datediff(day, 0, @EndDate));

    declare @Results table
	(
		txID int,
		txMID int, --added knc 5/22/2012 DE10400
		txTimestamp smalldatetime,
		txGamingDate smalldatetime,
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff nvarchar(260),
		txQty int,
		txSerialNo nvarchar(260),
		txFromLocation nvarchar(260)		
	);
	
    --
    -- Populate all transactions within the time span passed that are issues
    --	
    insert into @Results
	(
		txID,
		txMID ,
		txTimestamp,
		txGamingDate,
		txTransTypeID,
		txTransTypeName,
		txStaff,
		txQty,
		txSerialNo,
		txFromLocation	
	)
    select
		ivt.ivtInvTransactionID,
	    isnull(ivt.ivtMasterTransactionID,ivt.ivtInvTransactionID),
		ivt.ivtInvTransactionDate,
		ivt.ivtGamingDate,
		ivt.ivtTransactionTypeID,
		tt.TransactionType,
		(s.FirstName + ' ' + s.LastName),
		isnull(ABS((SELECT TOP 1 itd.ivdDelta
				 FROM InvTransactionDetail itd
				 WHERE itd.ivdInvTransactionID = ivt.ivtInvTransactionID
				 ORDER BY ivdDelta ASC)), 0),
		ii.iiSerialNo,
		isnull((SELECT TOP 1 il.ilInvLocationName
						  FROM InvLocations il
						  JOIN InvTransactionDetail itd ON (itd.ivdInvLocationID = il.ilInvLocationID)
						  WHERE itd.ivdInvTransactionID = ivt.ivtInvTransactionID
						  ORDER BY ivdDelta ASC), '')
    from Operator o -- DE7586
        join ProductItem pi on pi.OperatorID = o.OperatorID -- DE7586
        join InventoryItem i on i.iiProductItemID = pi.ProductItemID -- DE7586
        join InvTransaction ivt on ivt.ivtInventoryItemID = i.iiInventoryItemID -- DE7586
        join TransactionType tt ON (tt.TransactionTypeID = ivt.ivtTransactionTypeID)
        join InventoryItem ii ON (ii.iiInventoryItemID = ivt.ivtInventoryItemID)
        join Staff s ON (s.StaffID = ivt.ivtStaffID)
    where ((ivt.ivtGamingDate >= @StartDate
        and ivt.ivtGamingDate < @EndDate)
        or	(ivt.ivtInvTransactionDate >= @StartDate and ivt.ivtInvTransactionDate <= @EndDate))	-- US3367
        and ivt.ivtTransactionTypeID = 23 -- Skip
        and (@OperatorID = 0 or o.OperatorID = @OperatorID) -- DE7586
        and (@StaffID = 0 or ivtStaffID = @StaffID);

    --
    -- Select our final result set
    -- 	
    select * from @Results;



















GO

