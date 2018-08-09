USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoicesSkips]    Script Date: 08/06/2013 14:11:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvoicesSkips]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvoicesSkips]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoicesSkips]    Script Date: 08/06/2013 14:11:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptInvoicesSkips] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports the skips per product that were imported into inventory from XML file>
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@InvoiceNumber as nvarchar(255)
AS
	
SET NOCOUNT ON

If @InvoiceNumber <> '0'

		Select	i.InvoiceNumber,
				i.InvoiceDate,
				ii.ItemName,
				ir.Series,
				ips.SkipStart,
				ips.SkipEnd
		From InvoiceItem ii
		Join Invoice i on ii.InvoiceId = i.InvoiceId
		Join InvoiceItemReceived ir on ii.ItemId = ir.ItemId
		Join InvoiceItemPack ip on ir.ItemReceivedId = ip.ItemReceivedId 
		Join InvoiceItemPackSkip ips on ip.ItemPackId = ips.ItemPackId
		Where i.InvoiceNumber = @InvoiceNumber
		Order By i.InvoiceDate, i.InvoiceNumber, ii.ItemName, ir.Series, ips.SkipStart, ips.SkipEnd;
Else		
		Select	i.InvoiceNumber,
				i.InvoiceDate,
				ii.ItemName,
				ir.Series,
				ips.SkipStart,
				ips.SkipEnd
		From InvoiceItem ii
		Join Invoice i on ii.InvoiceId = i.InvoiceId
		Join InvoiceItemReceived ir on ii.ItemId = ir.ItemId
		Join InvoiceItemPack ip on ir.ItemReceivedId = ip.ItemReceivedId 
		Join InvoiceItemPackSkip ips on ip.ItemPackId = ips.ItemPackId
		Where i.OperatorId = @OperatorID
		And (i.InvoiceDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		And i.InvoiceDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
		Order By i.InvoiceDate, i.InvoiceNumber, ii.ItemName, ir.Series, ips.SkipStart, ips.SkipEnd;
		
SET NOCOUNT OFF


GO

