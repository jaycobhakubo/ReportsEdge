USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkipsDateSessionStaff]    Script Date: 05/14/2019 16:07:26 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesSkipsDateSessionStaff]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesSkipsDateSessionStaff]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSkipsDateSessionStaff]    Script Date: 05/14/2019 16:07:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesSkipsDateSessionStaff]         
(        
 --=============================================        
 ----Author:  FortuNet (US3380)       
 ----Description: Reports barcoded paper sales and skips over a date range.
 ----             Grouped by Date, Session, Staff
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
	VoidedRegisterReceiptID int,
	GamingDate SmallDateTime,
	TransactionNumber int,
	TransactionType nvarchar(64),
	MachineID int,
	MachineDescription nvarchar(64),
	StaffName nvarchar(64),
	DTStamp DateTime,
	ItemID int
)

Declare @PaperScans table
(
	SerialNumber nvarchar(30),
	AuditNumber int,
	ProductName nvarchar(64),
	GamingSession int,
	VoidedRegisterReceiptID int,
	GamingDate SmallDateTime,
	TransactionNumber int,
	TransactionType nvarchar(64),
	MachineID int,
	MachineDescription nvarchar(64),
	StaffName nvarchar(64),
	DTStamp DateTime,
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
	StaffName,
	ItemID	    
)
Select	ii.iiSerialNo,
		ips.AuditNumber,
		rdi.ProductItemName,
		sp.GamingSession,
		rr.GamingDate,
		'Sold',
		s.FirstName + ' ' + s.LastName as StaffName,
		ips.InventoryItemId
From InvPaperTrackingPackStatus ips
Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Join Staff s on rr.StaffID = s.StaffID
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
			GamingDate,
			GamingSession,
			StaffName
	From @PaperScans
	Group By ItemID, SerialNumber, GamingDate, GamingSession, StaffName
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
		GamingSession,
		StaffName
	)
	Select	
		ivi.iiInventoryItemID,
		p.ItemName,
		ivi.iiSerialNo,
		ips.SkipStart,
		ips.SkipEnd,
		'Skipped MFG',
		ask.GamingDate,
		ask.GamingSession,
		ask.StaffName
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
	TransactionNumber,
	TransactionType,
	MachineID,
	MachineDescription,
	StaffName,
	DTStamp
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
	TransactionNumber,
	TransactionType,
	MachineID,
	MachineDescription,
	StaffName,
	DTStamp
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
		TransactionNumber,
		TransactionType,
		MachineID,
		MachineDescription,
		StaffName,
		DTStamp
From AuditRange
Group By ItemID, SerialNumber, TransactionNumber, rn, ProductName, GamingDate, GamingSession, DTStamp, MachineID, MachineDescription, StaffName, TransactionType
Order By ItemID, MIN(AuditNumber);

with AuditMissing
as
(
Select ItemID, SerialNumber, ProductName, AuditStart, AuditEnd, GamingDate, GamingSession, StaffName from (
	Select  Distinct(p1.AuditNumber),
			p1.SerialNumber as SerialNumber,
			p1.ProductName as ProductName,
			p1.ItemID as ItemID,
			p1.AuditNumber + 1 as AuditStart,
			p1.GamingDate as GamingDate,
			p1.GamingSession as GamingSession,
			p1.StaffName as StaffName,
			(	Select min(AuditNumber) - 1 
				from @PaperScans P2 
				where	p2.AuditNumber > p1.AuditNumber 
						and p2.ItemID = p1.ItemID 
						and p2.GamingDate = p1.GamingDate 
						and p2.GamingSession = p1.GamingSession 
						and p2.StaffName = p1.StaffName
						) as AuditEnd
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
	GamingDate,
	GamingSession,
	StaffName
)
Select	SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		ItemID,
		'Skipped',
		GamingDate,
		GamingSession,
		StaffName
From AuditMissing am
where NOT EXISTS  (	Select AuditStart 
					From @Results r
					Where r.ItemID = am.ItemID
						and r.AuditStart = am.AuditStart)
	and AuditEnd - AuditStart + 1 < 50;	


/* -tmp Not sure what this is tyring to do
with AuditMissing
as (
	Select	Distinct(p1.AuditNumber),
			NextAuditNumber = p1.AuditNumber + 1,
			p1.SerialNumber,
			p1.ItemID,
			p1.ProductName,
			p1.GamingDate,
			p1.GamingSession,
			p1.StaffName
	From @PaperScans p1 left join @PaperScans p2 on p1.AuditNumber = p2.AuditNumber - 1 
	Where p2.AuditNumber is null
	and p1.AuditNumber <> (Select MAX(AuditNumber)
							From @PaperScans p
							Where p.ItemID = p1.ItemID)
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
	GamingSession,
	StaffName
)
Select	SerialNumber,
		NextAuditNumber,
		NextAuditNumber,
		ProductName,
		ItemID,
		'Skipped',
		GamingDate,
		GamingSession,
		StaffName
From AuditMissing am
where NOT EXISTS  (Select AuditStart 
				From @Results r
				Where r.ItemID = am.ItemID
				and r.AuditStart = am.NextAuditNumber);
*/

-- Return our resultset

Select	--rn,
		ItemID,
		SerialNumber,
		AuditStart,
		AuditEnd,
		(AuditEnd - AuditStart) + 1 as Quantity,
		ProductName,
		GamingSession,
		GamingDate,
		TransactionType,
		StaffName
From @Results
Group By GamingDate, GamingSession, StaffName, ItemID, SerialNumber, ProductName, AuditStart, AuditEnd, TransactionType
Order By GamingDate, GamingSession, StaffName, ProductName, SerialNumber, AuditStart 

End

SET NOCOUNT OFF
 















GO

