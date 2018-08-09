USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicSales]    Script Date: 05/21/2013 11:19:12 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicSales]    Script Date: 05/21/2013 11:19:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptElectronicSales]
------ ============================================================================
-- Author:		Satish Anju
-- Description:	Electronic Sales with Card Ranges.

-- 2012.01.11 SA: New report
-- 2012.02.09 SA: Included CBB electronic Sales
-- 2012.02.16 jkn: Reworked, removed card ranges and streamlined some of the
--  calculations
-- 2012.02.21 jkn: DE10084 On game cards were not being counted properly
---2012.03.15 bsb: DE100190, DE10139 On game cards were not being counted properly
-- 2012.04.30 bsb: DE10319 
-- 2012.05.14 knc: (DE10388)Serial# on Voided Pack not showing
-- 2012.06.20 jkn: Only count the cards from one part of a continuation game
-- 2013.02.27 knc: DE10815 - Fixed NoOfCards Count Calculation.
-- 2013.05.21 tmp: DE10953 - Change the code to use the FindElectronicSales function. 
-- 2015091(knc): Add coupon sales into the total electronic sales.
------ ============================================================================
--declare
@OperatorID int,
@StartDate datetime,
@EndDate datetime,
@Session int

as
begin

declare @ElectronicSales table
(
	 RegisterReceiptID int
	,OriginalRegisterReceiptID int
	,VoidedRegisterReceiptID int
	,StaffID int
	,GamingSession int
	,TransactionNumber int
	,DTStamp datetime
	,SerialNumber nvarchar(64)
	,PackNumber int
	,NoOfCards int
	,Price money
)

Insert into @ElectronicSales
Select	0,
		elecsales.OriginalRegisterReceiptID,
		elecsales.VoidedRegisterReceiptID,
		elecsales.StaffID,
		elecsales.GamingSession,
		elecsales.ReceiptNumber,
		elecsales.TransactionDTS,
		ISNULL(elecsales.SerialNumber, elecsales.ClientIdentifier),
		elecsales.PackNumber,
		elecsales.CardsSold,
		elecsales.SalesAmount + cpn.CouponSales
From FindElectronicSales (@OperatorID, @StartDate, @EndDate, @Session) elecsales
left join FindCouponSalesByTransaction (@OperatorID, @StartDate, @EndDate, @Session) cpn on elecsales.ReceiptNumber = cpn.TransactionNumber


select * from @ElectronicSales 

end



GO

