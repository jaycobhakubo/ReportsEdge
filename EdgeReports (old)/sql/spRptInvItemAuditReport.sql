USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvItemAuditReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvItemAuditReport]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
CREATE PROCEDURE [dbo].[spRptInvItemAuditReport]
	@OperatorID as int,
	@ProductTypeID as Int,
	@SerialNo as nvarchar(30),
	@InventoryItemID as int
	--@TabName as nvarchar,
	--@FormNo as nvarchar,
	--@ProductItemID as int,
	--@InvoiceNo as nvarchar,
	--@ManufacturerID as int,
	--@VendorID as int,
	----@FirstIssueDate as datetime,
	--@RetireDate as datetime,
	--@LastIssueDate as datetime,
	--@InPlayOnly as bit,
	--@RetiredONly as bit,
	--@CardCutID as int,
	--@StartDate as smalldatetime,
	--@EndDate as smalldatetime,
	--@StaffID as int
	 
AS

SET NOCOUNT ON;	

--create table #InventoryAudit
--	(iiInventoryItemID int,
--	 iiProductItemID int,
--	 iiSerialNo nvarchar(30),
--	 iiInvoiceNo nvarchar(30),
--	 iiInvoiceQty int,
--	 iiStartCount int,
--	 iiCostPerItem money,
--	 iiPricePerItem money,
--	 iiTaxRate money,
--	 iiTaxID nvarchar(30),
--     iiManufacturerID int,
--     iiVendorID int,
--     iiCardCutID int,
--	 iiUp int,
--	 iiRangeStart int,
--	 iirangeEnd int,
--	 iiTabName nvarchar(30),
--	 iiFormNumber nvarchar(30),
--	 iiHoldPercentage money,
--	 iiReduceAtRegister bit,
--     iiStartLocationID int,
--	 iiCurrentCount int,
--	 iiVoids int,
--	 iiSkips int,
--	 iiInvoiceDate datetime,
--	 iiReceivedDate datetime,
--	 iiFirstIssueDate datetime,
--	 iiLastIssueDate datetime,
--     --iiFirstPlayDate datetime,
--	 --iiLastPlayDate datetime,
--	 iiRetiredDate datetime,
--	 ProductType nvarchar(50),
--	 ItemName nvarchar(64),
--	 OperatorID int,
--	 ProductTypeID int,
--	 ProductGroupID int,
--	 GroupName nvarchar(64),
--	 ManufacturerName nvarchar(64),
--	 VendorName nvarchar(64),
--	 ilInvLocationName nvarchar(30),
--     ccCardCutName nvarchar(10),
--	 ccHValue int,
--	 ccVValue int, 
--	 ccOn int
--	)
	
	
	select iiInventoryItemID, iiProductItemID, iiSerialNo, iiInvoiceNo, iiInvoiceQty,
	 iiStartCount, iiCostPerItem, iiPricePerItem, iiTaxRate, iiTaxID, iiManufacturerID, 
     iiVendorID, iiCardCutID, iiUp, iiRangeStart, iirangeEnd, iiTabName, iiFormNumber,
	 iiHoldPercentage, iiReduceAtRegister, iiStartLocationID, iiCurrentCount, iiVoids,
	 iiSkips, iiInvoiceDate, iiReceivedDate, iiFirstIssueDate, iiLastIssueDate, iiRetiredDate, 
		   InvTransaction.*, 
			D1.*,D2.*, 
			IL1.ilInvLocationName, IL2.ilInvLocationName,
			ProductType, P.OperatorID,
			ItemName, P.ProductTypeID, P.ProductGroupID,
			ManufacturerName, VendorName, IL.ilInvLocationName,
			ccCardCutName, ccOn, TransactionType, FirstName
	from InventoryItem
		join productitem P (nolock) on iiproductitemid = P.productitemid
		join ProductType PT (nolock) on P.ProductTypeID = PT.ProductTypeID
		left Join InvLocations IL (nolock) on iiStartLocationID = ilInvlocationID
		left join Manufacturer (nolock) on iimanufacturerID = manufacturerID
		left join Vendor (nolock) on iiVendorID = VendorID
		left join CardCuts (nolock) on iiCardCutID = ccCardCutID
		Join InvTransaction (nolock) on iiInventoryItemID = ivtInventoryItemID
		left join InvTransactionDetail d1 (nolock) on ivtInvTransactionID = d1.ivdInvTransactionID
		left join InvTransactionDetail d2 (nolock) on d1.ivdInvTransactionID = d2.ivdInvTransactionID
		Left join InvLocations IL1 (nolock) on D1.ivdInvLocationID = IL1.ilInvlocationID
		Left Join InvLocations IL2 (nolock) on D2.ivdInvLocationID = IL2.ilInvlocationID
		Left Join Machine (nolock) on D1.ivdInvLocationID = MachineID
		Join TransactionType (nolock) on ivtTransactionTypeID = TransactionTypeID
		Left Join Staff (nolock) on ivtStaffID = StaffID
	Where P.OperatorID = @OperatorID
		and (@ProductTypeID = 0 or PT.ProductTypeID = @ProductTypeID) 
		and (@SerialNo = 0 or iiSerialNo = @SerialNo)
		and (@InventoryItemID = 0 or iiInventoryItemID = @InventoryItemID);
		
		


--Select * from #InventoryAudit


--Drop Table #InventoryAudit
GO


