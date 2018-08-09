USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoiceHistory_Summary]    Script Date: 08/11/2015 14:41:43 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvoiceHistory_Summary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvoiceHistory_Summary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoiceHistory_Summary]    Script Date: 08/11/2015 14:41:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptInvoiceHistory_Summary] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports the number of sets received for each products imported into inventory from then invoice XML file>
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME
AS
	
SET NOCOUNT ON


-- Testing
-- Declare	@OperatorID as int,
--		@StartDate	AS DATETIME,
--		@EndDate	AS DATETIME

--Set @OperatorID = 1
--Set @StartDate = '01/01/2013'
--Set @EndDate = '07/31/2013'

Select	ii.ItemName,
		COUNT(ii.ItemName) as Quantity
From InvoiceItem ii
Join Invoice i on ii.InvoiceId = i.InvoiceId
Join InvoiceItemReceived ir on ii.ItemId = ir.ItemId
Join InvoiceItemPack ip on ir.ItemReceivedId = ip.ItemReceivedId
Where i.OperatorId = @OperatorID
And CAST(CONVERT(varchar(12), i.InvoiceDate, 101) as smalldatetime) >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And CAST(CONVERT(varchar(12), i.InvoiceDate, 101) as smalldatetime) <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
Group By ii.ItemName
Order By ii.ItemName
		
		

GO

