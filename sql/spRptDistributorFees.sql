USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDistributorFees]    Script Date: 04/14/2014 08:43:48 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDistributorFees]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDistributorFees]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDistributorFees]    Script Date: 04/14/2014 08:43:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptDistributorFees] 
-- ============================================================================
-- Author:		Travis Pollock
-- Description:	<Reports the distributor fees over a date range for billing>
-- 2014.04.11 tmp: US3341 - Add distributor fees for Crystal Ball Bingo.
-- ============================================================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME
AS
	
SET NOCOUNT ON

-- Testing
--Declare @OperatorID	AS INT,
--	@StartDate	AS DATETIME,
--	@EndDate	AS DATETIME

--Set @OperatorID = 1
--Set @StartDate = '12/01/2013'
--Set @EndDate = '12/07/2013'

declare @taxRate money;
select @taxRate = (SalesTax / 100.0) from Hall where HallID = (select top 1 HallID from Hall);
print @taxRate;

Declare @ElectronicSales table
(
	RegisterReceiptID int,
	GamingDate SmallDateTime,
	TransactionNumber int,
	SessionPlayedID int,
	GamingSession int,
	DeviceID int,
	MachineID int,
	CharityID int,
	CharityName nvarchar(128)
)
Insert @ElectronicSales
Select	rd.RegisterReceiptID,
		rr.GamingDate,
		rr.TransactionNumber,
		sp.SessionPlayedID,
		sp.GamingSession,
		(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 isnull(ulSoldToMachineID, ulUnitNumber) FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		sp.CharityId,
		c.Name
From RegisterDetail rd
Join RegisterReceipt rr on (rd.RegisterReceiptID = rr.RegisterReceiptID)
Join RegisterDetailItems rdi on (rd.RegisterDetailID = rdi.RegisterDetailID)
Join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
Left Join Charity c on (sp.CharityId = c.CharityId)
Where rr.OperatorID = @OperatorID
And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And rr.SaleSuccess = 1
And rdi.CardMediaID = 1 -- Electronic
And rd.VoidedRegisterReceiptID is null
Group By rr.GamingDate, sp.SessionPlayedID, sp.GamingSession, rd.RegisterReceiptID, rr.TransactionNumber, sp.CharityId, c.Name
Order By rr.GamingDate, sp.GamingSession;

DECLARE @Results TABLE
(
	GamingDate SmallDateTime,
	GamingSession INT,
	CharityName NVARCHAR(128),
	DeviceName NVARCHAR(32),
	UnitsSold INT,
	UnitFee MONEY,
	TotFee Money,
	TaxRate Money            
);
Insert into @Results
(
	GamingDate,
	GamingSession,
	CharityName,
	DeviceName,
	UnitsSold,
	UnitFee,
	TotFee,
	TaxRate
)     
Select 	e.GamingDate,
		e.GamingSession,
		e.CharityName,
		isnull(d.DeviceType, 'Pack') as DeviceName,
		Count(Distinct e.MachineID)as UnitsSold,	
		0,
		0,
		@taxRate
From @ElectronicSales e
Left Join Device d on (e.DeviceID = d.DeviceID)
Group By e.GamingDate, e.GamingSession, e.CharityName, e.SessionPlayedID, d.DeviceType;

---- Start US3341 --- Insert Crystal Ball Bingo cards sold ----------------
With cteCBBFees (Name, Fee)
As
(
Select Case when ddf.ddfDistDeviceFeeTypeID = 5 
				then 'Electronic'
			Else 'Paper' End,
		ddf.ddfDeviceFee
From DistributorDeviceFees ddf
Where ddf.ddfOperatorID = @OperatorID
And ddf.ddfDistDeviceFeeTypeID in (5, 6)
And ddf.ddfDeviceFee <> 0
)
	Insert into @Results
	(
		GamingDate,
		GamingSession,
		CharityName,
		DeviceName,
		UNitsSold,
		TaxRate,
		UnitFee
	)	
	Select	rr.GamingDate,
			sp.GamingSession,
			c.Name,
			cm.CardMediaName,
			Sum(rd.Quantity * (rdi.Qty * rdi.CardCount)) as CardCount,
			@taxRate,
			cbf.Fee
	From RegisterReceipt rr
				Join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				Join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
				Join CardMedia cm on cm.CardMediaID = rdi.CardMediaID
				Join cteCBBFees cbf on cm.CardMediaName = cbf.Name
				Left Join Charity c on (sp.CharityId = c.CharityId)
	Where	rr.OperatorID = @OperatorID
	And		rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And		rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And		rr.SaleSuccess = 1
	And		rd.VoidedRegisterReceiptID is null
	And		rdi.GameTypeID = 4
	Group By rr.GamingDate, sp.GamingSession, c.Name, cm.CardMediaName, cbf.Fee
	Order By cm.CardMediaName

---- End US3341 ------------------------------------------------------------

UPDATE @Results
SET UnitFee = ddf.ddfDeviceFee
FROM @Results r
	JOIN Device d ON (d.DeviceType = r.DeviceName)
	JOIN DistributorDeviceFees ddf ON (ddf.ddfDeviceID = d.DeviceID)
WHERE ddf.ddfOperatorID = @OperatorID
	AND ddf.ddfDeviceID = d.DeviceID
	AND ddf.ddfDistDeviceFeeTypeID = 1
	AND r.UnitsSold >= ddf.ddfMinRange
	AND r.UnitsSold <= ddf.ddfMaxRange;

UPDATE @Results SET UnitFee = 0
WHERE UnitFee IS NULL;

update @Results set totFee = (UnitFee * UnitsSold);

Select	GamingDate,
		GamingSession,
		CharityName,
		DeviceName,
		SUM(UnitsSold) as UnitsSold,
		UnitFee,
		SUM(TotFee) as TotFee,
		TaxRate,
		SUM(TotFee) * (TaxRate + 1) as Total
From @Results
Group By CharityName, GamingDate, GamingSession, DeviceName, UnitFee, TaxRate
Order By CharityName, GamingDate, GamingSession, DeviceName;

SET NOCOUNT OFF


GO

