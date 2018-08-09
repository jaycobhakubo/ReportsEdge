USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryUsage]    Script Date: 12/12/2013 15:02:45 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryUsage]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryUsage]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryUsage]    Script Date: 12/12/2013 15:02:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <12/05/2013>
-- Description:	<Inventory Usage - Returns the products inventory sales.
--               Based off of the spRptPaperTransactionDetail2>
-- =============================================

CREATE PROCEDURE [dbo].[spRptInventoryUsage]
	
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@Session	as int
AS

BEGIN
	
	SET NOCOUNT ON;

    -- setup start and end dates
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 1, datediff(day, 0, @EndDate));
    
    declare @Results table
    (
        MasterTransId int,
        GamingDate smalldatetime,
        GamingSession int,
        ProductName nvarchar(128),
        SerialNumber nvarchar(60),
        IssuedTo nvarchar(260),
        StartNumber int,
        EndNumber int,
		Skipped int,
        Issued int,
        Returned int,
		Damaged int,
        Sold int,
        Price money,
        Value money
    );
    
    with MasterTransactions as
    (
        select distinct isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) as MasterTransId
        from InvTransaction it
            join InvTransactionDetail itd on (it.ivtInvTransactionID = itd.ivdInvTransactionID)
            join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
            join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
            left join InvLocations INV on INV.ilInvLocationID=itd.ivdInvLocationID
            left join Staff ITS on (ITS.StaffID=INV.ilStaffID)
            left join Staff IBS on IBS.StaffID=it.ivtStaffID
      
        where it.ivtGamingDate >= @StartDate
            and it.ivtGamingDate < @EndDate
            and	it.ivtTransactionTypeID IN (3, 23, 25, 27, 32)
            and (@OperatorID = 0 or pri.OperatorID = @OperatorID)
            and (@Session = 0 or it.ivtGamingSession = @Session)
    ),
    LastInvTransaction as
    (
        select it.*,
            isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) as MasterTransId,
            row_number() over (partition by isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) order by it.ivtInvTransactionID desc) as RowNum
        from InvTransaction it
    )
    insert into @Results
    (
        MasterTransId,
        GamingDate,
        GamingSession,
        ProductName,
        SerialNumber,
        IssuedTo,
        StartNumber,
        EndNumber,
		Skipped,
        Issued,
        Returned,
		Damaged,
        Sold,
        Price,
        Value
    )
    select mt.masterTransId,
        lit.ivtGamingDate,
        lit.ivtGamingSession,
        pri.ItemName,
        ii.iiSerialNo,
        s.FirstName + N' ' + s.LastName + ' (' + cast(s.StaffID as nvarchar) + ')',
        dbo.GetInventoryTransStartNumber(mt.masterTransId),
        dbo.GetInventoryTransEndNumber(mt.masterTransId),
		dbo.GetInventoryTransSkipCount(mt.masterTransId),
        dbo.GetInventoryTransIssueCount(mt.masterTransId),
        dbo.GetInventoryTransReturnCount(mt.masterTransId),
		dbo.GetInventoryTransDamageCount(mt.MasterTransId),
        null,
        lit.ivtPrice,
        null
	from MasterTransactions mt
	    join LastInvTransaction lit on (mt.masterTransId = lit.MasterTransId)
        join InventoryItem ii on (lit.ivtInventoryItemID = ii.iiInventoryItemID)
        join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
        left join InvLocations il on (il.ilInvLocationID = dbo.GetInventoryTransIssueToLocation(mt.masterTransId))
        left join Staff s on (il.ilStaffID = s.StaffID)
    where lit.RowNum = 1;
    
    -- Setup the Quantity and Value
    update @Results
    set Sold = Issued - Returned - Skipped - Damaged,
        Value = (Issued - Returned - Skipped - Damaged) * Price;
        
    -- Setup the start and end numbers
    update @Results
    set StartNumber = null,
        EndNumber = null
    where StartNumber = 0 and EndNumber = 0;
                           
        
    select
        GamingDate,
        GamingSession,
        ProductName,
        SerialNumber,
        IssuedTo,
        StartNumber,
        EndNumber,
		Skipped,
        Issued,
        Returned,
		Damaged,
        Sold,
        Price,
        Value
    from @Results
    order by ProductName, SerialNumber, IssuedTo, StartNumber, EndNumber 
END

GO

