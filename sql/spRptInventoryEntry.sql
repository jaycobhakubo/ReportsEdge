USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryEntry]    Script Date: 06/25/2014 11:58:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryEntry]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryEntry]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryEntry]    Script Date: 06/25/2014 11:58:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptInventoryEntry] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports inventory that was received over a date range>
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME
AS
	
SET NOCOUNT ON

--Declare @StartDate as DateTime,
--		@EndDate as DateTime,
--		@OperatorID as Int

--Set @StartDate = '08/16/2013'
--Set @EndDate = '08/16/2013'
--Set @OperatorID = 1

Select	pi.ItemName,
		it.ivtGamingDate,
		ii.iiReceivedDate,
		ii.iiSerialNo,
		itd.ivdDelta,
		(ii.iiCostPerItem / ii.iiStartCount) * itd.ivdDelta as Value,
		it.ivtStaffID,
		s.FirstName + ' ' + s.LastName as Staff,
		Case when tt.TransactionTypeID = 22 Then 'Manual Adjustment'
			Else tt.TransactionType End as TransactionType
From InventoryItem ii join InvTransaction it on ii.iiInventoryItemID = it.ivtInventoryItemID
join InvTransactionDetail itd on it.ivtInvTransactionID = itd.ivdInvTransactionID
join TransactionType tt on it.ivtTransactionTypeID = tt.TransactionTypeID
join ProductItem pi on ii.iiProductItemID = pi.ProductItemID
join ProductType pt on pi.ProductTypeID = pt.ProductTypeID
join Staff s on it.ivtStaffID = s.StaffID
Where Cast(it.ivtInvTransactionDate as date) >=  @StartDate
And Cast(it.ivtInvTransactionDate as date) <=  @EndDate
And pi.OperatorID = @OperatorID
And tt.TransactionTypeID in (22, 28)  --Manual Inventory Adjustment, Inventory Receiving

Set NOCOUNT OFF




GO

