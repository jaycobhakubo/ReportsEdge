USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkips]    Script Date: 10/02/2015 17:02:30 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesSkips]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesSkips]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkips]    Script Date: 10/02/2015 17:02:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesSkips]         
(        
 --=============================================        
 ----Author:  FortuNet (US4176)       
 ----Description: Reports barcoded paper sales and skips over a date range.
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
	ItemID int
)

Declare @PaperScans table
(
	SerialNumber nvarchar(30),
	AuditNumber int,
	ProductName nvarchar(64),
	GamingSession int,
	GamingDate SmallDateTime,
	TransactionType nvarchar(64),
	ItemID int
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
	ItemID	    
)
Select	ii.iiSerialNo,
		ips.AuditNumber,
		rdi.ProductItemName,
		sp.GamingSession,
		rr.GamingDate,
		'Sold',
		ips.InventoryItemId
From InvPaperTrackingPackStatus ips
Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where rr.OperatorID = @OperatorID
And RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And rr.SaleSuccess = 1
And rd.VoidedRegisterReceiptID is null
And rr.SaleSuccess = 1;

--- Get the skipped audit numbers from the manufacturer
with AuditSkips
as (Select	ItemID,
			SerialNumber,
			MIN(AuditNumber) as AuditStart,
			MAX(AuditNumber) as AuditEnd,
			GamingDate
	From @PaperScans
	Group By ItemID, SerialNumber, GamingDate
	)
	Insert into @Results
	(
		ItemID,
		ProductName,
		SerialNumber,
		AuditStart,
		AuditEnd,
		TransactionType,
		GamingDate
	)
	Select	
		ivi.iiInventoryItemID,
		p.ItemName,
		ivi.iiSerialNo,
		ips.SkipStart,
		ips.SkipEnd,
		'Skipped MFG',
		ask.GamingDate
	From InvoiceItemPackSkip ips join InvoiceItemPack iip on ips.ItemPackId = iip.ItemPackId
	Join InvoiceItemReceived iir on iip.ItemReceivedId = iir.ItemReceivedId
	Join InvoiceItem ii on ii.ItemId = iir.ItemId
	Join Invoice i on ii.InvoiceId = i.InvoiceId
	Join InventoryItem ivi on i.InvoiceNumber = ivi.iiInvoiceNo and ivi.iiAuditNumberStart = iip.PackStart and ivi.iiAuditNumberEnd = iip.PackEnd
	Join ProductItem p on ivi.iiProductItemID = p.ProductItemID
	Join AuditSkips ask on ivi.iiInventoryItemID = ask.ItemID 
	Where i.OperatorId = @OperatorID
	and iir.Series = ivi.iiSerialNo
    and (ips.SkipStart >= ask.AuditStart and ips.SkipStart <= ask.AuditEnd); 

With AuditRange
as (Select ROW_NUMBER() Over (Partition By ItemID Order By AuditNumber) - AuditNumber as rn,
	ItemID,
	SerialNumber,
	ProductName,
	AuditNumber,
	GamingDate,
	GamingSession,
	TransactionType
	From @PaperScans
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
	TransactionType
)
Select
		rn,
		ItemId,
		SerialNumber,
		ProductName,
		MIN(AuditNumber) as AuditStart,
		MAX(AuditNumber) as AuditEnd,
		GamingDate,
		GamingSession,
		TransactionType
From AuditRange
Group By ItemID, SerialNumber, rn, ProductName, GamingDate, GamingSession, TransactionType
Order By ItemID, MIN(AuditNumber);

with AuditMissing
as
(
Select ItemID, SerialNumber, ProductName, AuditStart, AuditEnd, GamingDate from (
	Select  Distinct(p1.AuditNumber),
			p1.SerialNumber as SerialNumber,
			p1.ProductName as ProductName,
			p1.ItemID as ItemID,
			p1.AuditNumber + 1 as AuditStart,
			p1.GamingDate as GamingDate,
		(Select min(AuditNumber) - 1 from @PaperScans P2 where p2.AuditNumber > p1.AuditNumber and p2.ItemID = p1.ItemID) as AuditEnd
	From @PaperScans P1
		left join @PaperScans P3 on P1.AuditNumber = P3.AuditNumber - 1 and P1.ItemID = P3.ItemID
	Where P3.AuditNumber is null)
	as P4
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
	GamingDate
)
Select	SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		ItemID,
		'Skipped',
		GamingDate
From AuditMissing am
where NOT EXISTS  (Select AuditStart 
				From @Results r
				Where r.ItemID = am.ItemID
				and r.AuditStart = am.AuditStart);	


-- Return our resultset

Select	ItemID,
		SerialNumber,
		AuditStart,
		AuditEnd,
		(AuditEnd - AuditStart) + 1 as Quantity,
		ProductName,
		GamingDate,
		TransactionType
From @Results
Group By GamingDate, ItemID, SerialNumber, ProductName, AuditStart, AuditEnd, TransactionType
Order By GamingDate, ProductName, SerialNumber, AuditStart 

End

SET NOCOUNT OFF
 




GO

