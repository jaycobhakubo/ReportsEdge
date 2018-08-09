USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryUsage]    Script Date: 03/03/2014 14:16:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryUsage]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryUsage]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryUsage]    Script Date: 03/03/2014 14:16:24 ******/
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
       
    declare @IssueResults table
    (
        InvTransID	int,
        MasterTransId int,
        GamingDate smalldatetime,
        GamingSession int,
        ProductName nvarchar(128),
        SerialNumber nvarchar(60),
        StaffID int,
        StartNumber int,
        EndNumber int,
        Skipped int,
        Issued int,
        Returned int,
        Damaged int,
        Quantity int,
        Price money,
        Value money,
        RowNum int
    );

-- Issues
Insert into @IssueResults
Select	it.ivtInvTransactionID,
		it.ivtMasterTransactionID,
		it.ivtGamingDate,
		it.ivtGamingSession,
		pri.ItemName,
		ii.iiSerialNo,
		inv.ilStaffID,
		it.ivtStartNumber,	
		it.ivtEndNumber,
		0,
		itd.ivdDelta,
		0,
		0,
		(it.ivtEndNumber - it.ivtStartNumber) + 1,
		it.ivtPrice,
		((it.ivtEndNumber - it.ivtStartNumber) + 1) * it.ivtPrice,
		row_number() over (partition by isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) order by it.ivtInvTransactionID desc) as RowNum
from InvTransaction it
join InvTransactionDetail itd on (it.ivtInvTransactionID = itd.ivdInvTransactionID)
join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
left join InvLocations INV on INV.ilInvLocationID=itd.ivdInvLocationID
Where it.ivtGamingDate >= @StartDate
and	it.ivtGamingDate <= @EndDate
and	(it.ivtGamingSession = @Session or @Session = 0)
and it.ivtTransactionTypeID = 25 --Issue
and inv.ilInvLocationTypeID = 3 --Staff
and (pri.OperatorID = @OperatorID or @OperatorID = 0)                        
        
-- Returns
Declare @ReturnResults table
(
	MasterTransID int,
	Returned	int
)
Insert into @ReturnResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID --And il.ilInvLocationTypeID = 3
Where it.ivtGamingDate >= @StartDate
and	it.ivtGamingDate <= @EndDate
and	(it.ivtGamingSession = @Session or @Session = 0)
and it.ivtTransactionTypeID = 3 --Return
and il.ilInvLocationTypeID = 3 --Staff
Group By it.ivtMasterTransactionID

Update @IssueResults
Set Returned = rr.Returned
From @ReturnResults rr join @IssueResults ir on rr.MasterTransID = ISNULL(ir.MasterTransID, ir.InvTransID)

-- Skips
Declare @SkippedResults table
(
	MasterTransID int,
	Skipped	int
)
Insert into @SkippedResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID --And il.ilInvLocationTypeID = 3
Where it.ivtGamingDate >= @StartDate
and	it.ivtGamingDate <= @EndDate
and	(it.ivtGamingSession = @Session or @Session = 0)
and it.ivtTransactionTypeID = 23 --Skipped
and il.ilInvLocationTypeID = 3 --Staff
Group By it.ivtMasterTransactionID

Update @IssueResults
Set Skipped = sr.Skipped
From @SkippedResults sr join @IssueResults ir on sr.MasterTransID = ISNULL(ir.MasterTransID, ir.InvTransID)

--Damages
Declare @DamagedResults table
(
	MasterTransID int,
	Damaged	int
)
Insert into @DamagedResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID --And il.ilInvLocationTypeID = 3
Where it.ivtGamingDate >= @StartDate
and	it.ivtGamingDate <= @EndDate
and	(it.ivtGamingSession = @Session or @Session = 0)
and it.ivtTransactionTypeID = 27 --Damaged
and il.ilInvLocationTypeID = 3 --Staff
Group By it.ivtMasterTransactionID

Update @IssueResults
Set Damaged = dr.Damaged
From @DamagedResults dr join @IssueResults ir on dr.MasterTransID = ISNULL(ir.MasterTransID, ir.InvTransID)


--Setup the start and end numbers
update @IssueResults
set StartNumber = null,
    EndNumber = null
where StartNumber = 0 and EndNumber = 0;

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
Select	isnull(MasterTransId, invTransID),
		GamingDate,
		GamingSession,
		ProductName,
		SerialNumber,
		 s.LastName + N', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar) + ')',
		StartNumber,
		EndNumber - Returned,
		Skipped,
		Issued,
		Returned,
		Damaged,
		Issued - Returned,
		Price,
		(Issued - Returned) * Price
From @IssueResults ir join Staff s on ir.StaffID = s.StaffID
Where RowNum = 1                   
   
 -- Setup the Quantity and Value
update @Results
set Sold = Issued - Returned - Skipped - Damaged,
    Value = (Issued - Returned - Skipped - Damaged) * Price;
        
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

