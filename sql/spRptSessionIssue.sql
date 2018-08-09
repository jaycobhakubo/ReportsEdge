USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionIssue]    Script Date: 04/14/2015 15:18:37 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionIssue]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionIssue]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionIssue]    Script Date: 04/14/2015 15:18:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE  [dbo].[spRptSessionIssue] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<US3689: Reports inventory that was issued for the date, session, and staff>
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@Session	as int,
	@StaffID	as int

AS
	
SET NOCOUNT ON

---- Testing -------------------------------------
--Set @OperatorID = 1
--Set @StartDate = '04/07/2015'
--Set @EndDate = '04/07/2015'
--Set @Session = 1
--Set @StaffID = 0
---------------------------------------------------

Declare @EndDate as DateTime
Set @EndDate = @StartDate

declare @Results table
( 	
	 StaffName				nvarchar(64)
	,Product				nvarchar(64)
	,SerialNumber			nvarchar(30)
	,Quantity				int
	,Price					money	
)

insert into @Results
(
		StaffName,
		Product,
		SerialNumber,
		Quantity,
		Price
)	

Select	ITS.LastName + ', ' + ITS.FirstName + ' (' + convert(nvarchar(10), ITS.StaffID) + ')' as StaffName,
		p.ItemName,
		ii.iiSerialNo,
		Case ivt.ivtStartNumber when 0 then ivd.ivdDelta Else
		(ivt.ivtEndNumber - ivt.ivtStartNumber) + 1 End as Quantity,
		ivt.ivtPrice
From InvTransaction ivt join InventoryItem ii on ivt.ivtInventoryItemID = ii.iiInventoryItemID
join ProductItem p on ii.iiProductItemID = p.ProductItemID
join InvTransactionDetail ivd on ivd.ivdInvTransactionID = ivt.ivtInvTransactionID
join InvLocations inv on inv.ilInvLocationID = ivd.ivdInvLocationID
join Staff its on its.StaffID = inv.ilStaffID
Where p.OperatorID = @OperatorID
and ivt.ivtGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and ivt.ivtGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)   
and ivt.ivtTransactionTypeID = 25 --Issue
and (@Session = 0 or ivt.ivtGamingSession = @Session)
and inv.ilStaffID <> 0
and (@StaffID=0 or inv.ilStaffID = @StaffID)

IF EXISTS(Select StaffName From @Results)
BEGIN
Select	StaffName,
		Product,
		SerialNumber,
		SUM(Quantity) as Quantity,
		Price
From @Results
Group By StaffName, Product, SerialNumber, Price
Order By StaffName, Product, SerialNumber, Price
End
Else 
Begin
Insert into @Results
(
	StaffName
)
Select s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(10), s.StaffID) + ')' as StaffName
From Staff s
where s.StaffID = @StaffID
Select	StaffName,
		Product,
		SerialNumber,
		SUM(Quantity) as Quantity,
		Price
From @Results
Group By StaffName, Product, SerialNumber, Price
Order By StaffName, Product, SerialNumber, Price
End

Set NOCOUNT OFF



GO

