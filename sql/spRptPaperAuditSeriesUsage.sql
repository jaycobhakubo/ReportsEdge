USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperAuditSeriesUsage]    Script Date: 04/17/2015 08:47:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperAuditSeriesUsage]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperAuditSeriesUsage]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperAuditSeriesUsage]    Script Date: 04/17/2015 08:47:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <5/21/2015>
-- Description:	<Paper usage history for each serial number>
-- 2015.04.17 DE12427: If zero was entered for a damaged audit number the report would not
-- be able to determine the correct audit ranges for the damaged audit numbers and subsequent issue ranges.
-- Changed the report to report the start and end audit numbers that were used and the total quantity of 
-- skips, damaged, bonanza trades.  
-- =============================================

CREATE PROCEDURE [dbo].[spRptPaperAuditSeriesUsage]
	
@OperatorID	as int,
@SerialNumber as nvarchar(30)

AS

BEGIN
	
SET NOCOUNT ON;
		
---- Testing ---------------------------------------------------

--Declare @OperatorID as int,
--		  @SerialNumber as nvarchar(30)

--Set @OperatorID = 1
--Set @SerialNumber = 369933
---------------------------------------------------------------
    
set @SerialNumber = isnull(@SerialNumber,0)

declare @Results table
(
    MasterTransId int,
    GamingDate smalldatetime,
    GamingSession int,
    ProductName nvarchar(128),
    SerialNumber nvarchar(60),
    InventoryItemID int,
    TransactionType nvarchar(64),
    IssuedTo nvarchar(260),
    StartNumber int,
    EndNumber int,
    Issued int,
    Returned int,
    Sold int,
    Price money,
    Value money,
    Skips int,
    Damaged int,
    BonanzaTrades int
);
   
declare @IssueResults table
(
    InvTransID	int,
    MasterTransId int,
    GamingDate smalldatetime,
    GamingSession int,
    InventoryItemID int,
    StartCount int,
    ProductName nvarchar(128),
    SerialNumber nvarchar(60),
    StaffID int,
    TransactionType nvarchar(64),
    StartNumber int,
    EndNumber int,
    Issued int,
    Returned int,
    Quantity int,
    Damaged int,
    Skips int, --- New
    BonanzaTrades int, ---New
    Price money,
    Value money,
    RowNum int
);

-- Get the issue transactions for the serial number.
Insert into @IssueResults
Select	it.ivtInvTransactionID,
		it.ivtMasterTransactionID,
		it.ivtGamingDate,
		it.ivtGamingSession,
		ii.iiInventoryItemID,
		ii.iiStartCount,
		pri.ItemName,
		ii.iiSerialNo,
		inv.ilStaffID,
		t.TransactionType,
		it.ivtStartNumber,	
		it.ivtEndNumber,
		itd.ivdDelta,   --- Issued
		0,   
		(it.ivtEndNumber - it.ivtStartNumber) + 1,
		0,
		0,
		0,
		it.ivtPrice,
		((it.ivtEndNumber - it.ivtStartNumber) + 1) * it.ivtPrice,
		row_number() over (partition by isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) order by it.ivtInvTransactionID desc) as RowNum
from InvTransaction it
join InvTransactionDetail itd on (it.ivtInvTransactionID = itd.ivdInvTransactionID)
join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
join ProductType pt on (pri.ProductTypeID = pt.ProductTypeID)
left join InvLocations INV on INV.ilInvLocationID=itd.ivdInvLocationID
join TransactionType t on (t.TransactionTypeID = it.ivtTransactionTypeID)
Where ii.iiSerialNo = @SerialNumber
and it.ivtTransactionTypeID = 25 --Issue
and inv.ilInvLocationTypeID = 3 --Staff
and (pri.OperatorID = @OperatorID or @OperatorID = 0) 
and pt.ProductTypeID = 16 -- Paper


-------------New for damaged audit number = 0 -----------------------------
-- Get the quanity damaged for each serial number issued.
Declare @DamagedResults table
(
	MasterTransID int,
	Damaged int
)
Insert into @DamagedResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID
join InventoryItem ii on it.ivtInventoryItemID = ii.iiInventoryItemID 
Where ii.iiSerialNo = @SerialNumber
and it.ivtTransactionTypeID = 27 --Damaged
and il.ilInvLocationTypeID = 3 --Staff.,mg
Group By it.ivtMasterTransactionID   

Update @IssueResults
Set Damaged = dr.Damaged
From @DamagedResults dr join @IssueResults ir on dr.MasterTransId = ISNULL(ir.MasterTransId, ir.InvTransID)


-- Get the quanity skipped for each serial number issued.
Declare @SkipsResults table
(
	MasterTransID int,
	Skips int
)
Insert into @SkipsResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID
join InventoryItem ii on it.ivtInventoryItemID = ii.iiInventoryItemID 
Where ii.iiSerialNo = @SerialNumber
and it.ivtTransactionTypeID = 23 --Skip
and il.ilInvLocationTypeID = 3 --Staff.,mg
Group By it.ivtMasterTransactionID   

Update @IssueResults
Set Skips = sr.Skips
From @SkipsResults sr join @IssueResults ir on sr.MasterTransId = ISNULL(ir.MasterTransId, ir.InvTransID)
	
--- Get the Bonanza Trades
Declare @BonanzaTradesResults table
(
	MasterTransID int,
	BonanzaTrades int
)
Insert into @BonanzaTradesResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID
join InventoryItem ii on it.ivtInventoryItemID = ii.iiInventoryItemID 
Where ii.iiSerialNo = @SerialNumber
and it.ivtTransactionTypeID = 24 --Bonanza Trades
and il.ilInvLocationTypeID = 3 --Staff.,mg
Group By it.ivtMasterTransactionID   

Update @IssueResults
Set BonanzaTrades = br.BonanzaTrades
From @BonanzaTradesResults br join @IssueResults ir on br.MasterTransId = ISNULL(ir.MasterTransId, ir.InvTransID)

-- Get the quantity returned for each serial number issued.
Declare @ReturnResults table
(
	MasterTransID int,
	Returned	int
)
Insert into @ReturnResults
Select  it.ivtMasterTransactionID,
		SUM(ivdDelta) * -1
From InvTransactionDetail itd join InvTransaction it on it.ivtInvTransactionID = itd.ivdInvTransactionID
Join InvLocations il on itd.ivdInvLocationID = il.ilInvLocationID
join InventoryItem ii on it.ivtInventoryItemID = ii.iiInventoryItemID 
Where ii.iiSerialNo = @SerialNumber
and it.ivtTransactionTypeID = 3 --Return
and il.ilInvLocationTypeID = 3 --Staff.,mg
Group By it.ivtMasterTransactionID                   
        
-- Update the issued transactions with the return quantity
Update @IssueResults
Set Returned = rr.Returned
From @ReturnResults rr join @IssueResults ir on rr.MasterTransID = ISNULL(ir.MasterTransID, ir.InvTransID)

-- Insert the updated issued starting and ending audit numbers
insert into @Results
    (
        MasterTransId,
        GamingDate,
        GamingSession,
        ProductName,
        SerialNumber,
        InventoryItemID,
        TransactionType,
        IssuedTo,
        StartNumber,
        EndNumber,
        Issued,
        Returned,
        Skips,
        Damaged,
        BonanzaTrades,
        Sold,
        Price,
        Value
    ) 
Select	isnull(MasterTransId, invTransID),
		GamingDate,
		GamingSession,
		ProductName,
		SerialNumber,
		InventoryItemID,
		TransactionType,
		 s.LastName + N', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar) + ')',
		StartNumber,
		EndNumber - Returned,
		Issued,
		Returned,
		Skips,
		Damaged,
		BonanzaTrades,
		Issued - Returned,
		Price,
		(Issued - Returned - Skips - Damaged - BonanzaTrades) * Price
From @IssueResults ir join Staff s on ir.StaffID = s.StaffID
Where RowNum = 1    


---- Final Results table
Declare @FinalResults table
(
		MasterTransId int,
		GamingDate smalldatetime,
		GamingSession int,
		ProductName nvarchar(128),
		SerialNumber nvarchar(60),
		InventoryItemID int,
		TransactionType nvarchar(64),
		IssuedTo nvarchar(260),
		StartNumber int,
		EndNumber int,
		Issued int,
		Returned int,
		Skips int,
		Damaged int,
		BonanzaTrades int,
		Quantity int,
		Vendor nvarchar(100),
		Manufacturer nvarchar(100),
		Price money,
		Value money, 
		StartCount int,
		TaxID nvarchar(30),
		RangeStart int,
		RangeEnd int,
		FirstIssueDate datetime,
		LastIssueDate datetime,
		CardCutName nvarchar(10),
		Up int,
		TotalCost money,
		InvoiceDate datetime,
		InvoiceNumber nvarchar(30),
		CurrentCount int
)

Insert into @FinalResults
(
		MasterTransID,
		GamingDate,
		GamingSession,
		ProductName,
		SerialNumber,
		InventoryItemID,
		TransactionType,
		IssuedTo,
		StartNumber,
		EndNumber,
		Issued,
		Returned,
		Skips,
		Damaged,
		BonanzaTrades,
		Quantity,
		Price,
		Value
)
Select	MasterTransId,
        GamingDate,
        GamingSession,
        ProductName,
        SerialNumber,
        InventoryItemID,
        TransactionType,
        IssuedTo,
        StartNumber,
        EndNumber,
        Issued,
        Returned,
        Skips,
        Damaged,
        BonanzaTrades,
        Sold,
        Price,
        Value
From @Results r
    
-- Get the inventory item information
Insert into @FinalResults
( 
		TaxID,
		RangeStart,
		RangeEnd,
		SerialNumber,
		InventoryItemID,
		FirstIssueDate,
		LastIssueDate,
		CardCutName,
		Up,
		Vendor,
		Manufacturer,
		TotalCost,
		InvoiceDate,
		InvoiceNumber,
		StartCount,
		CurrentCount
)
Select	ii.iiTaxID,
		ii.iiRangeStart,
		ii.iiRangeEnd,
		ii.iiSerialNo,
		ii.iiInventoryItemID,
		ii.iiFirstIssueDate,
		ii.iiLastIssueDate,
		cc.ccCardCutName,
		ii.iiUp,
		v.VendorName,
		m.ManufacturerName,
		ii.iiCostPerItem,
		ii.iiInvoiceDate,
		ii.iiInvoiceNo,
		ii.iiStartCount,
		ii.iiCurrentCount
From InventoryItem ii
			join CardCuts cc on ii.iiCardCutID = cc.ccCardCutID
			left join Vendor v on ii.iiVendorID = v.VendorID
			left join Manufacturer m on ii.iiManufacturerID = m.ManufacturerID
Where ii.iiSerialNo = @SerialNumber


-- Get the inventory adjustments
Insert into @FinalResults
(
	MasterTransId,
	InventoryItemID,
	GamingDate,
	TransactionType,
	IssuedTo,
	Quantity
)			
Select	it.ivtInvTransactionID,
		it.ivtInventoryItemID,
		it.ivtInvTransactionDate,
		tt.TransactionType,
		 s.LastName + N', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar) + ')',
		itd.ivdDelta
From InvTransaction it join InvTransactionDetail itd on it.ivtInvTransactionID = itd.ivdInvTransactionID
			Join TransactionType tt on it.ivtTransactionTypeID = tt.TransactionTypeID
			Join Staff s on it.ivtStaffID = s.StaffID
Where it.ivtTransactionTypeID in (22, 28, 30)
And it.ivtInventoryItemID in (Select distinct InventoryItemID
								From @FinalResults)


-- Final resultset 		
select
	MasterTransId,
    GamingDate,
    GamingSession,
    ProductName,
    SerialNumber,
    InventoryItemID,
    TransactionType,
    IssuedTo,
    StartNumber,
    EndNumber,
    Issued,
    Returned,
    Skips,
    Damaged,
    BonanzaTrades,
    Quantity,
    Price,
    Value,
    TaxID,
	RangeStart,
	RangeEnd,
	FirstIssueDate,
	LastIssueDate,
	CardCutName,
	Up,
	Vendor,
	Manufacturer,
	TotalCost,
	InvoiceDate,
	InvoiceNumber,
	StartCount,
	CurrentCount
from @FinalResults
Order by StartNumber, EndNumber

END
	




GO

