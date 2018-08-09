USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryEntryByInvoice]    Script Date: 06/24/2014 14:46:13 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryEntryByInvoice]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryEntryByInvoice]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryEntryByInvoice]    Script Date: 06/24/2014 14:46:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptInventoryEntryByInvoice] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports inventory that was entered by invoice>
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
		pt.ProductType,
		ii.iiReceivedDate,
		ii.iiSerialNo,
		ii.iiStartCount,
		ii.iiInvoiceNo,
		ii.iiCostPerItem,
		it.ivtStaffID,
		s.FirstName + ' ' + s.LastName as Staff,
		tt.TransactionType
From InventoryItem ii join InvTransaction it on ii.iiInventoryItemID = it.ivtInventoryItemID
join TransactionType tt on it.ivtTransactionTypeID = tt.TransactionTypeID
join ProductItem pi on ii.iiProductItemID = pi.ProductItemID
join ProductType pt on pi.ProductTypeID = pt.ProductTypeID
join Staff s on it.ivtStaffID = s.StaffID
Where Cast(ii.iiReceivedDate as date) >=  @StartDate
And Cast(ii.iiReceivedDate as date) <=  @EndDate
And pi.OperatorID = @OperatorID
And tt.TransactionTypeID = 28  --Receive

Set NOCOUNT OFF


GO

