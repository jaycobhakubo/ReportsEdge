USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSalesSummary]    Script Date: 03/28/2014 14:43:22 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByDeviceSalesSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByDeviceSalesSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSalesSummary]    Script Date: 03/28/2014 14:43:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptSalesByDeviceSalesSummary]
-- =============================================
-- Author:		<Louis J. Landerman>
-- Description:	<>
-- 03/10/2011 BJS: DE7731: new subreport to retain as much existing code as possible.
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@Session	AS	INT
AS

SET NOCOUNT ON
    
-- Results table	
declare @Results table
--CREATE TABLE @Results
	(
		DeviceFee		MONEY,
		Tax				MONEY,
		Voids			MONEY,
		Returns			MONEY
	);

Declare @DeviceFees table
(
	ReceiptID int,
	DeviceFee money
)
Insert into @DeviceFees
(
	ReceiptID,
	DeviceFee
)
Select  rr.RegisterReceiptID,
		rr.DeviceFee
From RegisterReceipt rr
Join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
Left Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	And rd.VoidedRegisterReceiptID is null
Group By rr.RegisterReceiptID, rr.DeviceFee

--		
-- Insert Device Fee Rows		
--
INSERT INTO @Results
	(
		DeviceFee
	)    	
SELECT SUM(DeviceFee)
From @DeviceFees
	
--		
-- Insert Tax Rows		
--
INSERT INTO @Results
	(
		Tax
	)   
SELECT 
SUM(rd.SalesTaxAmt * rd.Quantity) 
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID IN (1, 3)
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL;

--		
-- Total Voids Rows		
--
INSERT INTO @Results
	(
		Voids
	)  
SELECT SUM(rd.Quantity * rdi.Qty * rdi.Price) FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)	
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL;
	
INSERT INTO @Results
	(
		Voids
	)  
SELECT SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price) FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)	
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NOT NULL;

--		
-- Total Returns Rows		
--
INSERT INTO @Results
	(
		Returns
	)    
SELECT SUM(rd.Quantity * rdi.Qty * rdi.Price) 
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)	
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL;


-- Return results!
SELECT	
		ISNULL(SUM(DeviceFee), 0.0) AS DeviceFee,
		ISNULL(SUM(Tax), 0.0) AS Tax,
		ISNULL(SUM(Voids), 0.0) AS Voids,
		ISNULL(SUM(Returns), 0.0) AS Returns
FROM @Results;

   
SET NOCOUNT OFF;












GO

