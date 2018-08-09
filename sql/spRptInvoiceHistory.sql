USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoiceHistory]    Script Date: 08/11/2015 14:45:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvoiceHistory]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvoiceHistory]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvoiceHistory]    Script Date: 08/11/2015 14:45:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptInvoiceHistory] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports the products that were imported into inventory from then invoice XML file>
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

		Select	i.InvoiceDate,
				s.FirstName,
				s.LastName,
				i.InvoiceNumber,
				ii.ItemName,
				i.InvoiceVendor,
				ir.Series,
				ii.DefaultPackCount,
				(ir.InvoicePrice / ir.Units) as Price,
				im.Name,
				ip.PackStart,
				ip.PackEnd,
				SUM((ips.SkipEnd - ips.SkipStart) + 1) as Skips
		From InvoiceItem ii
		Join Invoice i on ii.InvoiceId = i.InvoiceId
		Join InvoiceManufacturer im on ii.InvoiceMfgId = im.ManufacturerId
		Join InvoiceItemReceived ir on ii.ItemId = ir.ItemId
		Join InvoiceItemPack ip on ir.ItemReceivedId = ip.ItemReceivedId
		Left Join InvoiceItemPackSkip ips on ip.ItemPackId = ips.ItemPackId
		Join Staff s on i.StaffId = s.StaffID
		Where i.OperatorId = @OperatorID
		And CAST(CONVERT(varchar(12), i.InvoiceDate, 101) as smalldatetime) >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		And CAST(CONVERT(varchar(12), i.InvoiceDate, 101) as smalldatetime) <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		Group By ir.Series, i.InvoiceDate, s.FirstName, s.LastName, i.InvoiceNumber, ii.ItemName, i.InvoiceVendor, ii.DefaultPackCount, im.Name,
		ip.PackStart, ip.PackEnd, ir.InvoicePrice, ir.Units, ips.ItemPackId
		Order By ii.ItemName, ir.Series, ip.PackStart, ip.PackEnd;
		

GO

