USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSummary2]    Script Date: 02/14/2014 11:35:52 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByDeviceSummary2]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByDeviceSummary2]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByDeviceSummary2]    Script Date: 02/14/2014 11:35:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptSalesByDeviceSummary2]
-- =============================================
-- Author:		<FortuNet, Inc>
-- Description:	<Reports the number of devices sold and the sales per device.
--               Update to the spRptSalesByDeviceSummary so that new devices can be added
--				 without having to update the stored procedure.>
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@Session	AS	INT,
	@StaffID	AS	INT 
AS

Set NOCOUNT ON
-- ==================
-- Test code
--declare 
--@OperatorID	INT ,
--@StartDate	DATETIME ,
--@EndDate	DATETIME ,
--@Session	INT ,
--@StaffID  int 

--set @OperatorID	 = 1
--set @StartDate	 = '11/1/2013 00:00:00'
--set @EndDate	 = '11/30/2013 00:00:00'
--set @Session	 = 0
--set @StaffID   = 0


-- ====================

SET NOCOUNT ON

-- Results table	
Declare @TempRptSalesByDeviceSummary table
	(
		GamingDate DateTime,
		GamingSession Int,	
		DeviceID	Int,
		DeviceSales	Money,
		DeviceCount	Int
	)
		
--
-- Populate Device Lookup Table to matchup a device with a register receipt using
-- the UnLockLog for lookups.
-- DeviceID is of the first device the pack number is used in. Sold to Traveler, and then transfered to Tracker, counts Traveler as played. 

Declare @TempDevicePerReceiptDeviceSummary table
	(
		registerReceiptID	INT,
		deviceID			INT,
		soldToMachineID		INT,
		unitNumber			INT
	)
	
INSERT INTO @TempDevicePerReceiptDeviceSummary
	(
		registerReceiptID,
		deviceID,
		soldToMachineID,
		unitNumber
	)
SELECT	rr.RegisterReceiptID,
		(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 ulUnitNumber FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)
FROM RegisterReceipt rr
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)


INSERT INTO @TempRptSalesByDeviceSummary
(
	GamingDate,
	GamingSession,
	DeviceID,
	DeviceSales,
	DeviceCount
)
SELECT	rr.GamingDate,
		sp.GamingSession,
		dpr.DeviceID,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		Case When dpr.deviceID <= 2 Then COUNT(Distinct dpr.UnitNumber) -- Count crate loaded devices
		Else Count(Distinct dpr.SoldToMachineID) End  -- Count pack loaded devices
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN @TempDevicePerReceiptDeviceSummary dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
	and (@StaffID = 0 or rr.StaffID = @StaffID)
Group By rr.GamingDate, sp.GamingSession, dpr.DeviceID

Select	isnull(DeviceType, 'Un-Played') as DeviceType,
		SUM(DeviceSales) as DeviceSales,
		Sum(DeviceCount) as DeviceCount
From @TempRptSalesByDeviceSummary sbd left join Device d on sbd.DeviceID = d.DeviceID Group By DeviceType

SET NOCOUNT OFF














GO

