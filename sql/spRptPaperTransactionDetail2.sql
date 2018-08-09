USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail2]    Script Date: 05/04/2015 15:32:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperTransactionDetail2]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperTransactionDetail2]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail2]    Script Date: 05/04/2015 15:32:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


----------------------------------------------------------------------
-- 2014.02.20 tmp: DE11589 - Unable to generate report. Modified the report
--							so that it does not call scalar functions to get
--							Start, End, Issue, Return counts.
-- 2015.05.04 tmp: DE12457 - When paper was transferred and @StaffID <> 0 then
--							the paper would be reported for both the transferred to and from staff.
----------------------------------------------------------------------


CREATE PROCEDURE [dbo].[spRptPaperTransactionDetail2] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@Session	as int,
	@StaffID	as int	
AS
begin
    set nocount on;
    
    -- setup start and end dates
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 0, datediff(day, 0, @EndDate));
    
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
        Issued int,
        Returned int,
        Quantity int,
        Price money,
        Value money
    );
    
    --with MasterTransactions as
    --(
    --    select distinct isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) as MasterTransId
    --    from InvTransaction it
    --        join InvTransactionDetail itd on (it.ivtInvTransactionID = itd.ivdInvTransactionID)
    --        join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
    --        join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
    --        left join InvLocations INV on INV.ilInvLocationID=itd.ivdInvLocationID
    --        left join Staff ITS on (ITS.StaffID=INV.ilStaffID)
    --        left join Staff IBS on IBS.StaffID=it.ivtStaffID
      
    --    where it.ivtGamingDate >= @StartDate
    --        and it.ivtGamingDate <= @EndDate
    --        and	it.ivtTransactionTypeID IN (3, 23, 25, 27, 32)
    --        and (@OperatorID = 0 or pri.OperatorID = @OperatorID)
    --        and (@Session = 0 or it.ivtGamingSession = @Session)
    --        and (@StaffID=0 or INV.ilStaffID=@StaffID)
    --        and pri.ProductTypeID = 16 -- Paper only
    --),
    --LastInvTransaction as
    --(
    --    select it.*,
    --        isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) as MasterTransId,
    --        row_number() over (partition by isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) order by it.ivtInvTransactionID desc) as RowNum
    --    from InvTransaction it
      
    --)
 --   insert into @Results
 --   (
 --       MasterTransId,
 --       GamingDate,
 --       GamingSession,
 --       ProductName,
 --       SerialNumber,
 --       IssuedTo,
 --       StartNumber,
 --       EndNumber,
 --       Issued,
 --       Returned,
 --       Quantity,
 --       Price,
 --       Value
 --   )
 --   select mt.masterTransId,
 --       lit.ivtGamingDate,
 --       lit.ivtGamingSession,
 --       pri.ItemName,
 --       ii.iiSerialNo,
 --       s.LastName + N', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar) + ')',
 --       dbo.GetInventoryTransStartNumber(mt.masterTransId),
 --       dbo.GetInventoryTransEndNumber(mt.masterTransId),
 --       dbo.GetInventoryTransIssueCount(mt.masterTransId),
 --       dbo.GetInventoryTransReturnCount(mt.masterTransId),
 --       null,
 --       lit.ivtPrice,
 --       null
	--from MasterTransactions mt
	--    join LastInvTransaction lit on (mt.masterTransId = lit.MasterTransId)
 --       join InventoryItem ii on (lit.ivtInventoryItemID = ii.iiInventoryItemID)
 --       join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
 --       left join InvLocations il on (il.ilInvLocationID = dbo.GetInventoryTransIssueToLocation(mt.masterTransId))
 --       left join Staff s on (il.ilStaffID = s.StaffID)
 --       --select * from InvLocations
 --       --select * from Staff
 --   where lit.RowNum = 1;
    
 --   -- Setup the Quantity and Value
 --   update @Results
 --   set Quantity = Issued - Returned,
 --       Value = (Issued - Returned) * Price;
 --       --left join Staff s on (il.ilStaffID = s.StaffID
        
 --   -- Setup the start and end numbers
 --   update @Results
 --   set StartNumber = null,
 --       EndNumber = null
 --   where StartNumber = 0 and EndNumber = 0;
  
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
        Issued int,
        Returned int,
        Quantity int,
        Price money,
        Value money,
        RowNum int
    );

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
		itd.ivdDelta,
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
/* DE12457 and (inv.ilStaffID = @StaffID or @StaffID = 0) */
and (pri.OperatorID = @OperatorID or @OperatorID = 0) 

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
        Issued,
        Returned,
        Quantity,
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
		Issued,
		Returned,
		Issued - Returned,
		Price,
		(Issued - Returned) * Price
From @IssueResults ir join Staff s on ir.StaffID = s.StaffID
Where RowNum = 1  
and (s.StaffID = @StaffID or @StaffID = 0)            -- DE12457
             
   
--- Now for our resultset   
select MasterTransId,
    GamingDate,
    GamingSession,
    ProductName,
    SerialNumber,
    IssuedTo,
    StartNumber,
    EndNumber,
    Issued,
    Returned,
    Quantity,
    Price,
    Value
from @Results
order by IssuedTo, GamingDate, GamingSession, ProductName 

end;



































GO

