USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesHistoryBySerial]    Script Date: 10/02/2015 16:55:59 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesHistoryBySerial]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesHistoryBySerial]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesHistoryBySerial]    Script Date: 10/02/2015 16:55:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesHistoryBySerial]         
(        
 --=============================================        
 ----Author:  FortuNet (US3498)        
 ----Description: Reports barcoded sales history by serial number
 --=============================================        
 @OperatorID AS INT,        
 @SerialNumber AS NVARCHAR(64)
)        
AS        
BEGIN        
    SET NOCOUNT ON;

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
	VoidedRegisterReceiptID,
	GamingDate,
	TransactionNumber,
	TransactionType,
	MachineID,
	MachineDescription,
	StaffName,
	DTStamp,
	ItemID	    
)
Select	ii.iiSerialNo,
		ips.AuditNumber,
		rdi.ProductItemName,
		sp.GamingSession,
		rd.VoidedRegisterReceiptID,
		rr.GamingDate,
		rr.TransactionNumber,
		t.TransactionType,
		m.MachineID,
		m.MachineDescription,
		s.FirstName + ' ' + s.LastName as StaffName,
		rr.DTStamp,
		ips.InventoryItemId
From InvPaperTrackingPackStatus ips
Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Join Staff s on rr.StaffID = s.StaffID
Join Machine m on rr.SoldFromMachineID = m.MachineID
Join TransactionType t on rr.TransactionTypeID = t.TransactionTypeID
Where rr.OperatorID = @OperatorID
And (ii.iiSerialNo = @SerialNumber or @SerialNumber = 0)
And rr.SaleSuccess = 1

-- Insert Void transactions
Insert into @PaperScans
(
	SerialNumber,
	AuditNumber,
	ProductName,
	GamingSession,
	GamingDate,
	TransactionNumber,
	TransactionType,
	MachineID,
	MachineDescription,
	StaffName,
	DTStamp,
	ItemID	    
)	
Select	p.SerialNumber,
		p.AuditNumber,
		p.ProductName,
		p.GamingSession,
		rr.GamingDate,
		rr.TransactionNumber,
		Case when t.TransactionTypeID = 2 Then 'Void'
		 Else t.TransactionType End as TransactionType,
		m.MachineID,
		m.MachineDescription,
		s.FirstName + ' ' + s.LastName as StaffName,
		rr.DTStamp,
		p.ItemID		
From @PaperScans p join RegisterReceipt rr on p.VoidedRegisterReceiptID = rr.RegisterReceiptID
Join Staff s on rr.StaffID = s.StaffID
Join Machine m on rr.SoldFromMachineID = m.MachineID
Join TransactionType t on rr.TransactionTypeID = t.TransactionTypeID
Where p.VoidedRegisterReceiptID is not null;


--- Get the skipped audit numbers from the manufacturer
with AuditSkips
as (Select	ItemID,
			SerialNumber,
			MIN(AuditNumber) as AuditStart,
			MAX(AuditNumber) as AuditEnd
	From @PaperScans
	Where (SerialNumber = @SerialNumber or @SerialNumber = 0)
	Group By ItemID, SerialNumber
	)
	Insert into @Results
	(
		ItemID,
		ProductName,
		SerialNumber,
		AuditStart,
		AuditEnd,
		TransactionType
	)
	Select	
		ivi.iiInventoryItemID,
		p.ItemName,
		ivi.iiSerialNo,
		ips.SkipStart,
		ips.SkipEnd,
		'Skip MFG'
	From InvoiceItemPackSkip ips join InvoiceItemPack iip on ips.ItemPackId = iip.ItemPackId
	Join InvoiceItemReceived iir on iip.ItemReceivedId = iir.ItemReceivedId
	Join InvoiceItem ii on ii.ItemId = iir.ItemId
	Join Invoice i on ii.InvoiceId = i.InvoiceId
	Join InventoryItem ivi on i.InvoiceNumber = ivi.iiInvoiceNo and ivi.iiAuditNumberStart = iip.PackStart and ivi.iiAuditNumberEnd = iip.PackEnd
	Join ProductItem p on ivi.iiProductItemID = p.ProductItemID
	Join AuditSkips ask on ivi.iiInventoryItemID = ask.ItemID --and ips.SkipStart >= ask.AuditStart and ips.SkipStart <= ask.AuditEnd
	Where i.OperatorId = @OperatorID
	and (iir.Series = @SerialNumber or @SerialNumber = 0)
	and iir.Series = ivi.iiSerialNo
    and (ips.SkipStart >= ask.AuditStart and ips.SkipStart <= ask.AuditEnd); 
--	and (ips.SkipStart >= (Select MIN(AuditNumber) From @PaperScans) and ips.SkipStart <= (Select MAX(AuditNumber) From @PaperScans));

With AuditRange
as (Select ROW_NUMBER() Over (Partition By ItemID, TransactionNumber Order By AuditNumber) - AuditNumber as rn,
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
Select ItemID, SerialNumber, ProductName, AuditStart, AuditEnd from (
	Select  Distinct(p1.AuditNumber),
			p1.SerialNumber as SerialNumber,
			p1.ProductName as ProductName,
			p1.ItemID as ItemID,
			p1.AuditNumber + 1 as AuditStart,
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
	TransactionType
)
Select	SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		ItemID,
		'Skipped'
From AuditMissing am
where NOT EXISTS  (Select AuditStart 
				From @Results r
				Where r.ItemID = am.ItemID
				and r.AuditStart = am.AuditStart);	


-- Return our resultset

Select	rn,
		ItemID,
		SerialNumber,
		AuditStart,
		AuditEnd,
		ProductName,
		GamingSession,
		GamingDate,
		TransactionNumber,
		TransactionType,
		MachineID,
		MachineDescription,
		StaffName,
		DTStamp
From @Results
Order By SerialNumber, AuditStart 

End







GO

