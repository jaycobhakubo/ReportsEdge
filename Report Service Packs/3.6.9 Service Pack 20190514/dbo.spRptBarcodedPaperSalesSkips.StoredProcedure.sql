USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkips]    Script Date: 05/14/2019 16:06:56 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesSkips]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesSkips]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkips]    Script Date: 05/14/2019 16:06:56 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesSkips]         
(        
 --=============================================        
 ----Author:  FortuNet (US4176)       
 ----Description: Reports barcoded paper sales and skips over a date range.
 ----20161021 tmp: US4990 Added damaged packs.
 ---- 20190422 tmp: When two staff sold the sames series in different sessions, 
 ----			it would report any gaps as skipped.
 ---- 20190514 tmp: Do not include skips when the skip audit end - audit start is > 50.
 --=============================================        
 @OperatorID AS INT,        
 @StartDate AS DATETIME, 
 @EndDate AS DATETIME       
)        
AS        
BEGIN        
    SET NOCOUNT ON;

-------------------- For Testing ----------------------------
--Declare @OperatorID int,
--		@StartDate DateTime,
--		@EndDate DateTime,
--		@Session int
		
--Set @OperatorID = 1
--Set @StartDate = '08/01/2015'
--Set @EndDate = '08/31/2015'
--Set @Session = 0
---------------------------------------------------------------

Declare @Results table
(
	RN int,
	SerialNumber nvarchar(30),
	AuditStart int,
	AuditEnd int,
	ProductName nvarchar(64),
	GamingSession int,
	GamingDate SmallDateTime,
	TransactionType nvarchar(64),
	ItemID int,
	StaffID int
)

Declare @PaperScans table
(
	SerialNumber nvarchar(30),
	AuditNumber int,
	ProductName nvarchar(64),
	GamingSession int,
	GamingDate SmallDateTime,
	TransactionType nvarchar(64),
	ItemID int,
	StaffID	int
)
--- Insert Sales transactions
Insert Into @PaperScans
(
	SerialNumber,
	AuditNumber,
	ProductName,
	GamingSession,
	GamingDate,
	TransactionType,
	ItemID,
	StaffID	    
)
Select	ii.iiSerialNo,
		ips.AuditNumber,
		rdi.ProductItemName,
		sp.GamingSession,
		rr.GamingDate,
		'Sold',
		ips.InventoryItemId,
		rr.StaffID
From	InvPaperTrackingPackStatus ips
		Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
		Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
		Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
		Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where	rr.OperatorID = @OperatorID
		and RR.GamingDate >= CAST(CONVERT(varchar(12), '03/22/2019', 101) AS smalldatetime)
		and RR.GamingDate <= CAST(CONVERT(varchar(12), '03/22/2019', 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null;
						
-- US4990 Get the damaged audit number from an exchange
Insert Into @PaperScans
(
	SerialNumber,
	AuditNumber,
	ProductName,
	GamingSession,
	GamingDate,
	TransactionType,
	ItemID,
	StaffID	    
)
Select	ii.iiSerialNo,
		id.DamagedAuditNumber,
		rdi.ProductItemName,
		sp.GamingSession,
		sp.GamingDate,
		'Damaged',
		id.InventoryItemId,
		id.StaffId
From	InventoryMachineDamagedPaperUsage id 
		join RegisterDetailItems rdi on id.RegisterDetailItemId = rdi.RegisterDetailItemID
		Join InventoryItem ii on id.InventoryItemID = ii.iiInventoryItemID
		Join SessionPlayed sp on id.SessionPlayedID = sp.SessionPlayedID
Where	sp.OperatorID = @OperatorID
		And sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime);	
		
-- Get a pack that was not scanned but was damaged		
Insert into @PaperScans
(
	SerialNumber,
	AuditNumber,
	ProductName,
	GamingSession,
	GamingDate,
	TransactionType,
	ItemID,
	StaffID
)
select	ii.iiSerialNo,
		id.DamagedAuditNumber,
		p.ItemName,
		sp.GamingSession,
		sp.GamingDate,
		'Damaged',
		id.InventoryItemId,
		id.StaffId
from	InventoryMachineDamagedPaperUsage id
		join InventoryItem ii on id.InventoryItemId = ii.iiInventoryItemID
		join ProductItem p on ii.iiProductItemID = p.ProductItemID
		left join SessionPlayed sp on id.SessionPlayedId = sp.SessionPlayedID
where	sp.OperatorID = @OperatorID
		and sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and id.RegisterDetailItemId is null;
							

--- Get the skipped audit numbers from the manufacturer
with AuditSkips
as (Select	ItemID,
			SerialNumber,
			MIN(AuditNumber) as AuditStart,
			MAX(AuditNumber) as AuditEnd,
			GamingDate,
			StaffID
	From	@PaperScans
	Group By ItemID, 
			 SerialNumber, 
			 GamingDate,
			 StaffID
	)
	Insert into @Results
	(
		ItemID,
		ProductName,
		SerialNumber,
		AuditStart,
		AuditEnd,
		TransactionType,
		GamingDate,
		StaffID
	)
	Select	ivi.iiInventoryItemID,
			p.ItemName,
			ivi.iiSerialNo,
			ips.SkipStart,
			ips.SkipEnd,
			'Skipped MFG',
			ask.GamingDate,
			ask.StaffID
	From	InvoiceItemPackSkip ips 
			join InvoiceItemPack iip on ips.ItemPackId = iip.ItemPackId
			Join InvoiceItemReceived iir on iip.ItemReceivedId = iir.ItemReceivedId
			Join InvoiceItem ii on ii.ItemId = iir.ItemId
			Join Invoice i on ii.InvoiceId = i.InvoiceId
			Join InventoryItem ivi on i.InvoiceNumber = ivi.iiInvoiceNo 
									  and ivi.iiAuditNumberStart = iip.PackStart 
									  and ivi.iiAuditNumberEnd = iip.PackEnd
			Join ProductItem p on ivi.iiProductItemID = p.ProductItemID
			Join AuditSkips ask on ivi.iiInventoryItemID = ask.ItemID 
	Where	i.OperatorId = @OperatorID
			and iir.Series = ivi.iiSerialNo
			and ( ips.SkipStart >= ask.AuditStart 
				  and ips.SkipStart <= ask.AuditEnd
				 ); 

With AuditRange
as 
(
Select	ROW_NUMBER() Over (Partition By ItemID, TransactionType Order By AuditNumber) - AuditNumber as rn,
		ItemID,
		SerialNumber,
		ProductName,
		AuditNumber,
		GamingDate,
		GamingSession,
		TransactionType,
		StaffID
From	@PaperScans
)
Insert into @Results
(
		rn,
		ItemID,
		SerialNumber,
		ProductName,
		AuditStart,
		AuditEnd,
		GamingDate,
		GamingSession,
		TransactionType,
		StaffID
)
Select	rn,
		ItemId,
		SerialNumber,
		ProductName,
		MIN(AuditNumber) as AuditStart,
		MAX(AuditNumber) as AuditEnd,
		GamingDate,
		GamingSession,
		TransactionType,
		StaffID
From	AuditRange
Group By ItemID, 
		SerialNumber, 
		rn, 
		ProductName, 
		GamingDate, 
		GamingSession, 
		TransactionType,
		StaffID
Order By ItemID, 
		MIN(AuditNumber);

with AuditMissing
as
(
Select	ItemID, 
		SerialNumber, 
		ProductName, 
		AuditStart, 
		AuditEnd, 
		GamingDate,
		StaffID 
from (	Select	Distinct(p1.AuditNumber),
				p1.SerialNumber as SerialNumber,
				p1.ProductName as ProductName,
				p1.ItemID as ItemID,
				p1.AuditNumber + 1 as AuditStart,
				p1.GamingDate as GamingDate,
				p1.StaffID as StaffID,
				( Select	min(AuditNumber) - 1 
				  from		@PaperScans P2 
				  where		p2.AuditNumber > p1.AuditNumber 
							and p2.ItemID = p1.ItemID
							and p2.GamingDate = p1.GamingDate 
							and p2.GamingSession = p1.GamingSession 
							and p2.StaffID = p1.StaffID
				) as AuditEnd
		From	@PaperScans P1
				left join @PaperScans P3 on P1.AuditNumber = P3.AuditNumber - 1 
											and P1.ItemID = P3.ItemID
		Where P3.AuditNumber is null
	  ) as P4
where AuditEnd is not null
)
Insert into @Results
(
		SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		ItemID,
		TransactionType,
		GamingDate,
		StaffID
)
Select	SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		ItemID,
		'Skipped',
		GamingDate,
		StaffID
From	AuditMissing am
where	NOT EXISTS  ( Select AuditStart 
					  From @Results r
					  Where r.ItemID = am.ItemID
				      and r.AuditStart = am.AuditStart )
		and AuditEnd - AuditStart + 1 < 50;	


-- Return our resultset

Select	ItemID,
		SerialNumber,
		AuditStart,
		AuditEnd,
		(AuditEnd - AuditStart) + 1 as Quantity,
		ProductName,
		GamingDate,
		TransactionType
From	@Results
Group By GamingDate, 
		ItemID, 
		SerialNumber, 
		ProductName, 
		AuditStart, 
		AuditEnd, 
		TransactionType
Order By GamingDate, 
		ProductName, 
		SerialNumber, 
		AuditStart; 

End

SET NOCOUNT OFF;

GO

