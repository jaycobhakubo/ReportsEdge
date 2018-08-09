USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperScans]    Script Date: 08/20/2015 15:13:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperScans]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperScans]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperScans]    Script Date: 08/20/2015 15:13:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperScans]         
(        
 --=============================================        
 ----Author:  FortuNet (US4176)       
 ----Description: Reports barcoded paper sales based on what was scanned at the POS.
 --=============================================        
 @OperatorID AS INT,        
 @StartDate AS DATETIME,        
 @Session as int
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

Declare @EndDate as Datetime

Set @EndDate = @StartDate

Declare @Results table
(
		AuditStart int,
		AuditEnd int,
		Quantity int,
		ItemId int,
		rn int,
		StaffID int,
		StaffName nvarchar(64),
		GamingDate SmallDateTime,
		GamingSession int,
		ProductItemName nvarchar(64),
		SerialNumber int
)

-- Get the pack numbers that were sold at the POS for the date range and session.
Declare @PaperScans table
(
	ItemID int,
	startNum int,
	StaffID int,
	GamingDate datetime,
	ProductItemName nvarchar(64),
	GamingSession int,
	SerialNumber int
	
)
Insert into @PaperScans
(
	ItemID,
	startNum,
	StaffID,
	GamingDate,
	ProductItemName,
	GamingSession,
	SerialNumber
)
Select	
		itps.InventoryItemId,
		itps.AuditNumber,
		rr.StaffID,
		rr.GamingDate,
		rdi.ProductItemName,
		sp.GamingSession,
		ii.iiSerialNo
From InvPaperTrackingPackStatus itps
Join RegisterDetailItems rdi on itps.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join InventoryItem ii on itps.InventoryItemID = ii.iiInventoryItemID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where rr.OperatorID = @OperatorID
And RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and rr.SaleSuccess = 1    -- Check if the sale was a success
and rd.VoidedRegisterReceiptID is null    -- Do not include voided packs.
and (sp.GamingSession = @Session or @Session = 0);

--Select * From @PaperScans

-- Get the range of the continuous audit numbers sold. 

With AuditRange
	as (Select ROW_NUMBER() Over (Partition By ItemID Order By startNum) - startNum as rn,
		startNum,
		ItemId,
		StaffID,
		GamingDate,
		GamingSession,
		ProductItemName,
		SerialNumber
		From @PaperScans)
Insert into @Results

(		AuditStart,
		AuditEnd,
		Quantity,
		ItemId,
		rn,
		StaffID,
		StaffName,
		GamingDate,
		GamingSession,
		ProductItemName,
		SerialNumber
)		
Select	MIN(startNum) as AuditStart,
		MAX(startNum) as AuditEnd,
		(MAX(startNum) - MIN(startNum)) + 1 as Quantity,
		ItemId,
		rn,
		ar.StaffID,
		s.FirstName + ' ' + s.LastName as StaffName,
		GamingDate,
		GamingSession,
		ProductItemName,
		SerialNumber
From AuditRange ar join Staff s on ar.StaffID = s.StaffID
Group By GamingDate, GamingSession, ar.staffID, ItemId, rn, s.FirstName, s.LastName, ar.ProductItemName, ar.SerialNumber
Order By GamingDate, GamingSession, s. FirstName, s.LastName, ItemID, MIN(startNum)

Select *
From @Results

End

SET NOCOUNT OFF
 
GO
