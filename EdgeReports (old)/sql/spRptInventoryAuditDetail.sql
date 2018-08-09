USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryAuditDetail]    Script Date: 05/22/2012 10:35:35 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryAuditDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryAuditDetail]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryAuditDetail]    Script Date: 05/22/2012 10:35:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
create procedure [dbo].[spRptInventoryAuditDetail]
(
-- =============================================
-- Author:		    Barry J. Silver
-- Description:	    NIGC mandated audit report
--
-- 2011.10.31 bjs:  US2006 New report, cloned existing Inv Item Audit Report
-- 2011.11.18 bjs:  fix same date param selection
-- 2011.12.14 bjs:  DE728 improper header and detail lines
-- 2011.12.22 bsb:  DE9783:added new table resultsfinal, fixed current count, manufacturer table
-- 2012.01.24 bsb:  DE9728
-- 2012.05.17 knc:	DE10398 
-- =============================================
	@OperatorID as int,
	@ProductTypeID as Int,	
    @StartDate as datetime,
    @EndDate as datetime,
	@SerialNumber as nvarchar(30)
)	 
as
begin

set nocount on;	

set @SerialNumber = ISNULL(@SerialNumber,0)
set @ProductTypeID = ISNULL(@ProductTypeID, 0)
set @OperatorID = ISNULL(@OperatorID,0)


declare @Results table
(
    RowID               int identity(1,1),
    ProductItemID       int,
    SerialNo            nvarchar(30),
    TransactionID       int,
    MasterTransID       int,
    TransactionDate     datetime,
    GamingSession       int,
    TransactionType     nvarchar(64),
    ProductType         nvarchar(50),
    ItemName            nvarchar(64),
    TaxID               nvarchar(30),
    FirstIssueDate      datetime,
    LastIssueDate       datetime,
    RetireDate          datetime,

    StartLocation       nvarchar(64),
    StartCount          decimal(28,2),
    CurrentCount        decimal(28,2),
    RemovedCount        decimal(28,2),
    VendorName          nvarchar(100),
    InvoiceDate         datetime,
    ManufacturerName    nvarchar(64),
    OnUp                nvarchar(10),
    Up                  int,
    Cost                real,
    InvoiceNo           nvarchar(30), 
    RangeStart          int,
    RangeEnd            int,
    ParmRange           nvarchar(30), 

    TransactionTypeID   int,
    Staff               nvarchar(64),

    FromLocation        nvarchar(64),
    ToLocation          nvarchar(64),
    FromLocId           int,
    ToLocId             int,
    LocationID          int,
    IsStaffLocation     bit,

    Price               money,
    StartNumber         int,
    EndNumber           int,
    
    ReceiveQty          int,            -- 28
    MoveQty             int,            -- 21
    TransferQty         int,            -- 32
    AdjustQty           int,            -- 22
    IssueQty            int,            -- 25
    ReturnQty           int,            -- 3
    DamageQty           int,            -- 27
    SkipQty             int,            -- 23
    RetireQty           int,            -- 30
    SaleQty             int,            -- 1
    VoidSaleQty         int,            -- 2

    Value               decimal(28,2)   -- superbig for test data!
    
);


insert into @Results
(
    ProductItemID,
    SerialNo,
    TransactionID,
    MasterTransID,
    
    TransactionDate,
    GamingSession,
    TransactionType,

    ProductType,
    ItemName,

    TaxID,
    FirstIssueDate,
    LastIssueDate,
    RetireDate,

    --StartLocation,
    --StartCount,
    --CurrentCount,
    --RemovedCount,

    VendorName,
    InvoiceDate,
    ManufacturerName,
    OnUp,
    Up,
    Cost,    
    InvoiceNo,
    RangeStart,
    RangeEnd,
    ParmRange,

    TransactionTypeID,
    Staff,
    FromLocation,    
    ToLocation,
    FromLocId,
    ToLocId,
    LocationID,
    IsStaffLocation,
    Price,
    StartNumber,
    EndNumber,

    ReceiveQty,
    MoveQty,
    TransferQty,
    AdjustQty,
    IssueQty,
    ReturnQty,
    DamageQty,
    SkipQty,
    RetireQty,
    SaleQty,
    VoidSaleQty,
    Value
    
)
select 
      pi.ProductItemID
    , iiSerialNo 
    , ivtInvTransactionID
    , ivtMasterTransactionID

    , ivtInvTransactionDate
    , ivtGamingSession
    , tt.TransactionType   

    , pt.ProductType
    , pi.ItemName

    , iiTaxID
    , iiFirstIssueDate
    , iiLastIssueDate
    , iiRetiredDate

    , v.VendorName
    , iiInvoiceDate
    , m.imInvManufacturerName
    , ccCardCutName
    , ii.iiUp
    , iiCostPerItem
    , iiInvoiceNo       
    , iiRangeStart, iiRangeEnd

    , case when (iiRangeStart is null or iiRangeStart = 0) then 'None' else ( convert(nvarchar(10), iiRangeStart) + ' - ' + convert(nvarchar(10), iiRangeEnd) ) end [Range]
    
    , tt.TransactionTypeID
    , s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(6), s.StaffID) + ') '
    
    , case when d1.ivdDelta < 0 then loc1.ilInvLocationName else '' end [From]
    , case when d1.ivdDelta >= 0 then loc1.ilInvLocationName else '' end [To]

    , case when d1.ivdDelta <0 then loc1.ilInvLocationID else 0 end [FromLocId]
    , case when d1.ivdDelta >= 0 then loc1.ilInvLocationID else 0 end [ToLocId]
    , loc1.ilInvLocationID
    , lt.iltIsStaff
    , isnull(ivtPrice, 0)    
    , ivtStartNumber
    , ivtEndNumber
    
    , case when ivtTransactionTypeID = 28 then isnull(d1.ivdDelta, 0) else 0 end [Received]
    , case when ivtTransactionTypeID = 21 then isnull(d1.ivdDelta, 0) else 0 end [Moved]
    , case when ivtTransactionTypeID = 32 then isnull(d1.ivdDelta, 0) else 0 end [Transferred]
    , case when ivtTransactionTypeID = 22 then isnull(d1.ivdDelta, 0) else 0 end [Adjusted]
    , case when ivtTransactionTypeID = 25 then isnull(d1.ivdDelta, 0) else 0 end [Issued]
    , case when ivtTransactionTypeID = 3  then isnull(d1.ivdDelta, 0) else 0 end [Returned]
    , case when ivtTransactionTypeID = 27 then isnull(d1.ivdDelta, 0) else 0 end [Damaged]
    , case when ivtTransactionTypeID = 23 then isnull(d1.ivdDelta, 0) else 0 end [Skipped]
    , case when ivtTransactionTypeID = 30 then isnull(d1.ivdDelta, 0) else 0 end [Retired]
    , case when ivtTransactionTypeID = 1 and ii.iiReduceAtRegister = 1 then ISNULL(d1.ivdDelta,0) else 0 end [Sale]
    , case when ivtTransactionTypeID = 2 and ii.iiReduceAtRegister = 1 then ISNULL(d1.ivdDelta,0) else 0 end [VoidSale]
    
    , case when (ivtTransactionTypeID in (3, 21, 22, 23, 25, 27, 28, 30, 32) )
      then ( convert(decimal(28,2), isnull(ivtPrice, 0)) * (convert(decimal(28,2), isnull(d1.ivdDelta, 0))) )     -- TODO use d2???
      when (ivtTransactionTypeID in (1,2) ) and ii.iiReduceAtRegister =1
      then ( convert(decimal(28,2), isnull(ivtPrice, 0)) * (convert(decimal(28,2), isnull(d1.ivdDelta, 0))) )     -- TODO use d2???
      else 0
      end

from InvTransaction i
left join InvTransactionDetail d1 on i.ivtInvTransactionID = d1.ivdInvTransactionID
--left join InvTransactionDetail d2 on d1.ivdInvTransactionID = d2.ivdInvTransactionID
left join InvLocations loc1 on d1.ivdInvLocationID = loc1.ilInvLocationID
--left join InvLocations loc2 on d2.ivdInvLocationID = loc2.ilInvLocationID
left join InventoryItem ii on i.ivtInventoryItemID = ii.iiInventoryItemID
left join InvManufacturer m on ii.iiManufacturerID = m.imInvManufacturerID
left join ProductItem pi on ii.iiProductItemID = pi.ProductItemID
left join ProductType pt on pi.ProductTypeID = pt.ProductTypeID
left join Vendor v on ii.iiVendorID = v.VendorID
left join CardCuts cc on iiCardCutID = ccCardCutID
left join GameCategory gc on i.ivtGameCategoryId = gc.GameCategoryID
left join Staff s on i.ivtStaffID = s.StaffID
left join TransactionType tt on i.ivtTransactionTypeID = tt.TransactionTypeID
left join InvLocationTypes lt on loc1.ilInvLocationTypeID = lt.iltInvLocationTypeID
left join Operator o on pi.OperatorID = o.OperatorID

where
    --(ivtInvTransactionDate >= @StartDate and ivtInvTransactionDate <= @EndDate)
 (@ProductTypeID = 0 or pt.ProductTypeID = @ProductTypeID)
and (@SerialNumber = '0' or ii.iiSerialNo = @SerialNumber)
and (o.OperatorID = @OperatorID or @OperatorID = 0)
order by i.ivtInvTransactionID ;




declare @ResultsFinal table
(
    RowID               int identity(1,1),
    ProductItemID       int,
    SerialNo            nvarchar(30),
    TransactionID       int,
    MasterTransID       int,
    TransactionDate     datetime,
    GamingSession       int,
    TransactionType     nvarchar(64),
    ProductType         nvarchar(50),
    ItemName            nvarchar(64),
    TaxID               nvarchar(30),
    FirstIssueDate      datetime,
    LastIssueDate       datetime,
    RetireDate          datetime,

    StartLocation       nvarchar(64),
    StartCount          decimal(28,2),
    CurrentCount        decimal(28,2),
    RemovedCount        decimal(28,2),
    VendorName          nvarchar(100),
    InvoiceDate         datetime,
    ManufacturerName    nvarchar(64),
    OnUp                nvarchar(10),
    Up                  int,
    Cost                real,
    InvoiceNo           nvarchar(30), 
    RangeStart          int,
    RangeEnd            int,
    ParmRange           nvarchar(30), 

    TransactionTypeID   int,
    Staff               nvarchar(64),

    FromLocation        nvarchar(64),
    ToLocation          nvarchar(64),
    FromLocId           int,
    ToLocId             int,
    LocationID          int,
    IsStaffLocation     bit,

    Price               money,
    StartNumber         int,
    EndNumber           int,
    
    ReceiveQty          int,            -- 28
    MoveQty             int,            -- 21
    TransferQty         int,            -- 32
    AdjustQty           int,            -- 22
    IssueQty            int,            -- 25
    ReturnQty           int,            -- 3
    DamageQty           int,            -- 27
    SkipQty             int,            -- 23
    RetireQty           int,            -- 30
    SaleQty             int,            --1
    VoidSaleQty         int,            --2

    Value               decimal(28,2)   -- superbig for test data!
    
);

-- Attempt to adjust historic (changing through time) inventory levels at EACH location
declare @prodId int, @tranId int, @tranTypeId int, @fromId int, @toId int;
declare @issueQty int, @receiveQty int, @transferQty int, @damageQty int, @returnQty int, @skipQty int, @moveQty int;
declare @saleQty int, @VoidSaleQty int;
declare @lastProdId int, @lastFromId int, @lastTranId int, @lastToId int, @adjustQty int, @retireQty int;
declare @tranCount int;
declare @rowId int;
declare @isStaffLoc bit;
declare @fromIsStaffLoc bit;
declare @locId int;
declare @transactionDate datetime;
declare @currCount decimal(28,2);
--debug
--select * from @Results order by ProductItemID, TransactionID;
declare LEVELS cursor local fast_forward for
select 
 RowID,  ProductItemID, TransactionID, TransactionTypeID
, isnull(FromLocId,0), isnull(ToLocId,0)
, ReceiveQty, MoveQty, TransferQty, AdjustQty, IssueQty, ReturnQty, DamageQty, SkipQty, RetireQty, SaleQty, VoidSaleQty, LocationID, IsStaffLocation,TransactionDate
from @Results order by ProductItemID, TransactionID;

open LEVELS;
fetch next from LEVELS into @rowId, @prodId, @tranId, @tranTypeId, @fromId, @toId
, @receiveQty, @moveQty, @transferQty, @adjustQty, @issueQty, @returnQty, @damageQty, @skipQty, @retireQty, @saleQty,@voidSaleQty, @locId, @isStaffLoc, @transactionDate;

set @tranCount = 0;  
set @currCount = 0;
set @lastProdId = @prodId;
set @lastTranId = @tranId;
set @lastFromId = @fromId;

insert @ResultsFinal
( 
    ProductItemID,
    SerialNo,
    TransactionID,
    MasterTransID,
    
    TransactionDate,
    GamingSession,
    TransactionType,

    ProductType,
    ItemName,

    TaxID,
    FirstIssueDate,
    LastIssueDate,
    RetireDate,

    --StartLocation,
    --StartCount,
    --CurrentCount,
    --RemovedCount,

    VendorName,
    InvoiceDate,
    ManufacturerName,
    OnUp,
    Up,
    Cost,    
    InvoiceNo,
    RangeStart,
    RangeEnd,
    ParmRange,

    TransactionTypeID,
    Staff,
    FromLocation,    
    ToLocation,
    FromLocId,
    ToLocId,
    LocationID,
    IsStaffLocation,
    Price,
    StartNumber,
    EndNumber,

    ReceiveQty,
    MoveQty,
    TransferQty,
    AdjustQty,
    IssueQty,
    ReturnQty,
    DamageQty,
    SkipQty,
    RetireQty,
    SaleQty,
    VoidSaleQty,
    Value
  )
select 
  
    ProductItemID,
    SerialNo,
    TransactionID,
    MasterTransID,
    
    TransactionDate,
    GamingSession,
    TransactionType,

    ProductType,
    ItemName,

    TaxID,
    FirstIssueDate,
    LastIssueDate,
    RetireDate,

    --StartLocation,
    --StartCount,
    --CurrentCount,
    --RemovedCount,

    VendorName,
    InvoiceDate,
    ManufacturerName,
    OnUp,
    Up,
    Cost,    
    InvoiceNo,
    RangeStart,
    RangeEnd,
    ParmRange,

    TransactionTypeID,
    Staff,
    FromLocation,    
    ToLocation,
    FromLocId,
    ToLocId,
    LocationID,
    IsStaffLocation,
    Price,
    StartNumber,
    EndNumber,

    ReceiveQty,
    MoveQty,
    TransferQty,
    AdjustQty,
    IssueQty,
    ReturnQty,
    DamageQty,
    SkipQty,
    RetireQty,
    SaleQty,
    VoidSaleQty,
    Value
   
   from @Results
   where RowID = @rowId;
   

set @fromIsStaffLoc = (select  ltype.iltIsStaff from InvLocations loc
						join InvLocationTypes ltype on loc.ilInvLocationTypeID = ltype.iltInvLocationTypeID
						where loc.ilInvLocationID = @fromId);





update @Results set StartCount = @currCount where ProductItemID = @prodId 
                                                   and TransactionID = @tranId 
                                                   and RowID = @rowId
                                                   and IsStaffLocation = 0;
Update @ResultsFinal
	set StartCount = @currCount where TransactionID = @tranId;


                                                   
while @@fetch_status = 0

begin
   
    if( @prodId != @lastProdId )        -- New product
    begin        
        -- do an update here...
        
        
        
        set @fromIsStaffLoc = (select  ltype.iltIsStaff from InvLocations loc
						join InvLocationTypes ltype on loc.ilInvLocationTypeID = ltype.iltInvLocationTypeID
						where loc.ilInvLocationID = @fromId);

        set @lastProdId = @prodId;
        set @lastTranId = @tranId;
        set @lastFromId = @fromId;
        set @currCount = 0;
        set @tranCount = 0;
        update @Results set StartCount = @currCount where ProductItemID = @prodId and TransactionID = @tranId
        insert @ResultsFinal
		( 
		    ProductItemID,
			SerialNo,
			TransactionID,
			MasterTransID,
		    
			TransactionDate,
			GamingSession,
			TransactionType,

			ProductType,
			ItemName,

			TaxID,
			FirstIssueDate,
			LastIssueDate,
			RetireDate,

			--StartLocation,
			StartCount,
			--CurrentCount,
			--RemovedCount,

			VendorName,
			InvoiceDate,
			ManufacturerName,
			OnUp,
			Up,
			Cost,    
			InvoiceNo,
			RangeStart,
			RangeEnd,
			ParmRange,

			TransactionTypeID,
			Staff,
			FromLocation,    
			ToLocation,
			FromLocId,
			ToLocId,
			LocationID,
		    IsStaffLocation,
			Price,
			StartNumber,
			EndNumber,

			ReceiveQty,
			MoveQty,
			TransferQty,
			AdjustQty,
			IssueQty,
			ReturnQty,
			DamageQty,
			SkipQty,
			RetireQty,
			SaleQty,
			VoidSaleQty,
			Value
		  )
		  select 
		  
		   ProductItemID,
			SerialNo,
			TransactionID,
			MasterTransID,
		    
			TransactionDate,
			GamingSession,
			TransactionType,

			ProductType,
			ItemName,

			TaxID,
			FirstIssueDate,
			LastIssueDate,
			RetireDate,

			--StartLocation,
			StartCount,
			--CurrentCount,
			--RemovedCount,

			VendorName,
			InvoiceDate,
			ManufacturerName,
			OnUp,
			Up,
			Cost,    
			InvoiceNo,
			RangeStart,
			RangeEnd,
			ParmRange,

			TransactionTypeID,
			Staff,
			FromLocation,    
			ToLocation,
			FromLocId,
			ToLocId,
			LocationID,
		    IsStaffLocation,
			Price,
			StartNumber,
			EndNumber,

			ReceiveQty,
			MoveQty,
			TransferQty,
			AdjustQty,
			IssueQty,
			ReturnQty,
			DamageQty,
			SkipQty,
			RetireQty,
			SaleQty,
			VoidSaleQty,
			Value
		   
		   from @Results
		   where RowID = @rowId;
   
          update @Results 
          set StartCount = @currCount 
          where ProductItemID = @prodId and TransactionID = @tranId
    end;
    else if( @tranId != @lastTranId )       -- New transaction. Either one record or two per transaction
    begin
        -- do an update here...
        update @Results set StartCount = @currCount where ProductItemID = @prodId and TransactionID = @tranId
        print ''
        set @lastTranId = @tranId;
        
        insert @ResultsFinal
		( 
		    ProductItemID,
			SerialNo,
			TransactionID,
			MasterTransID,
		    
			TransactionDate,
			GamingSession,
			TransactionType,

			ProductType,
			ItemName,

			TaxID,
			FirstIssueDate,
			LastIssueDate,
			RetireDate,

			--StartLocation,
			StartCount,
			--CurrentCount,
			--RemovedCount,

			VendorName,
			InvoiceDate,
			ManufacturerName,
			OnUp,
			Up,
			Cost,    
			InvoiceNo,
			RangeStart,
			RangeEnd,
			ParmRange,

			TransactionTypeID,
			Staff,
			FromLocation,    
			ToLocation,
			FromLocId,
			ToLocId,
			LocationID,
		    IsStaffLocation,
			Price,
			StartNumber,
			EndNumber,

			ReceiveQty,
			MoveQty,
			TransferQty,
			AdjustQty,
			IssueQty,
			ReturnQty,
			DamageQty,
			SkipQty,
			RetireQty,
			SaleQty,
			VoidSaleQty,
			Value
		  )
		  select 
		  
		   ProductItemID,
			SerialNo,
			TransactionID,
			MasterTransID,
		    
			TransactionDate,
			GamingSession,
			TransactionType,

			ProductType,
			ItemName,

			TaxID,
			FirstIssueDate,
			LastIssueDate,
			RetireDate,

			--StartLocation,
			StartCount,
			--CurrentCount,
			--RemovedCount,

			VendorName,
			InvoiceDate,
			ManufacturerName,
			OnUp,
			Up,
			Cost,    
			InvoiceNo,
			RangeStart,
			RangeEnd,
			ParmRange,

			TransactionTypeID,
			Staff,
			FromLocation,    
			ToLocation,
			FromLocId,
			ToLocId,
			LocationID,
		    IsStaffLocation,
			Price,
			StartNumber,
			EndNumber,

			ReceiveQty,
			MoveQty,
			TransferQty,
			AdjustQty,
			IssueQty,
			ReturnQty,
			DamageQty,
			SkipQty,
			RetireQty,
			SaleQty,
			VoidSaleQty,
			Value
		   
		   from @Results
		   where RowID = @rowId;
   
        set @tranCount = 0;
    end;        
    else 
    begin
        -- This is the second of two transactions
        
        -- do an update here...
        update @Results 
		 set StartCount = @currCount
		 where ProductItemID = @prodId 
		       and TransactionID = @tranId
 
        update @ResultsFinal 
               set ToLocation = (select ToLocation from @Results
								 where RowID = @rowId)
			  where TransactionID = @tranId;
    end;
    --else
      begin
      update @Results 
		set StartCount = @currCount  
		where ProductItemID = @prodId 
               and TransactionID = @tranId 
               and RowID = @rowId
      end;
      
    -- For this record, all of these values EXCEPT one will be zero.  We just don't know which is zero.
    if @isStaffLoc = 0    
    begin
		set @currCount = @currCount+ @receiveQty +  @moveQty +  @transferQty +  @adjustQty +  @issueQty +  @returnQty +  @damageQty +  @skipQty +  @retireQty +@saleQty+@VoidSaleQty;
	end;	
    
    update @Results set CurrentCount = @currCount  where ProductItemID = @prodId 
                                                   and TransactionID = @tranId 
                                                   and RowID = @rowId
    Update @ResultsFinal
	set CurrentCount = @currCount where TransactionID = @tranId;;
    -- so we can determine if we are on the second of two transactions for a given transId
    set @tranCount = @tranCount + 1;
    
    -- get then next record from the cursor 
    fetch next from LEVELS into @rowId, @prodId, @tranId, @tranTypeId, @fromId, @toId
    , @receiveQty, @moveQty, @transferQty, @adjustQty, @issueQty, @returnQty, @damageQty, @skipQty, @retireQty,@saleQty,@voidSaleQty, @locId, @isStaffLoc, @transactionDate;
end;


-- cleanup
close LEVELS;
deallocate LEVELS;

-- Return our resultset

select *
into #a
from @ResultsFinal 







select   a. RowID  ,            
   a. ProductItemID ,      
    a.SerialNo       ,  
   a.TransactionID   ,  
   a.MasterTransID    ,  
   a.TransactionDate   ,  
   a.GamingSession      ,
  a.TransactionType     ,
 a.ProductType         ,
 a.ItemName            ,
    a.TaxID              ,
    a.FirstIssueDate   ,
    a.LastIssueDate     ,
    a.RetireDate         ,

    a.StartLocation ,       
    a.StartCount     ,    
    a.CurrentCount    ,   
    a.RemovedCount     ,   
    a.VendorName        ,
    a.InvoiceDate       ,
    a.ManufacturerName ,   
    a.OnUp    ,            
    a.Up       ,      
    a.Cost      ,      
    a.InvoiceNo  ,       
    a.RangeStart  ,    
    a.RangeEnd     ,   
    a.ParmRange     ,  

    a.TransactionTypeID ,
    a.Staff              ,

    a.FromLocation       ,
    a.ToLocation        ,
    a.FromLocId      ,
    a.ToLocId         ,  
    a.LocationID       ,   
    a.IsStaffLocation   , 

    a.Price      ,         
    a.StartNumber ,       
    a.EndNumber    ,       
    
    ReceiveQty    ,                 -- 28
    MoveQty        ,           -- 21
    TransferQty     ,              -- 32
    AdjustQty        ,             -- 22
    IssueQty          ,           -- 25
    ReturnQty          ,         -- 3
    DamageQty           ,         -- 27
    SkipQty              ,         -- 23
    RetireQty             ,      -- 30
    SaleQty                ,       --1
    VoidSaleQty       ,

    Value           
     from #a a join (select TransactionID  from #a 
where cast(CONVERT(VARCHAR(10),TransactionDate,10) as smalldatetime) >= cast(CONVERT(VARCHAR(10),@StartDate  ,10) as smalldatetime)
and cast(CONVERT(VARCHAR(10),TransactionDate,10) as smalldatetime) <= cast(CONVERT(VARCHAR(10),@EndDate   ,10) as smalldatetime)) b
on a.MasterTransID = b.TransactionID 
where a.MasterTransID is not null

union all 
select
 a. RowID  ,            
   a. ProductItemID ,      
    a.SerialNo       ,  
   a.TransactionID   ,  
   a.MasterTransID    ,  
   a.TransactionDate   ,  
   a.GamingSession      ,
  a.TransactionType     ,
 a.ProductType         ,
 a.ItemName            ,
    a.TaxID              ,
    a.FirstIssueDate   ,
    a.LastIssueDate     ,
    a.RetireDate         ,

    a.StartLocation ,       
    a.StartCount     ,    
    a.CurrentCount    ,   
    a.RemovedCount     ,   
    a.VendorName        ,
    a.InvoiceDate       ,
    a.ManufacturerName ,   
    a.OnUp    ,            
    a.Up       ,      
    a.Cost      ,      
    a.InvoiceNo  ,       
    a.RangeStart  ,    
    a.RangeEnd     ,   
    a.ParmRange     ,  

    a.TransactionTypeID ,
    a.Staff              ,

    a.FromLocation       ,
    a.ToLocation        ,
    a.FromLocId      ,
    a.ToLocId         ,  
    a.LocationID       ,   
    a.IsStaffLocation   , 

    a.Price      ,         
    a.StartNumber ,       
    a.EndNumber    ,       
    
    ReceiveQty    ,                 -- 28
    MoveQty        ,           -- 21
    TransferQty     ,              -- 32
    AdjustQty        ,             -- 22
    IssueQty          ,           -- 25
    ReturnQty          ,         -- 3
    DamageQty           ,         -- 27
    SkipQty              ,         -- 23
    RetireQty             ,      -- 30
    SaleQty                ,       --1
    VoidSaleQty       ,

    Value   
from #a a

where cast(CONVERT(VARCHAR(10),TransactionDate,10) as smalldatetime) >= cast(CONVERT(VARCHAR(10),@StartDate  ,10) as smalldatetime)
and cast(CONVERT(VARCHAR(10),TransactionDate,10) as smalldatetime) <= cast(CONVERT(VARCHAR(10),@EndDate   ,10) as smalldatetime)
and MasterTransID is null

end;

set nocount off;







GO


