USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportElectronicSales]    Script Date: 04/08/2014 08:41:01 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportElectronicSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportElectronicSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportElectronicSales]    Script Date: 04/08/2014 08:41:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptRegisterClosingReportElectronicSales]
@OperatorID	as	int,
@StartDate	as	datetime,
@EndDate	as	datetime,
@StaffID    as  int,
@Session	as	int,
@MachineID  as  int	


as begin

set nocount on;
--=============================================================================	
-- 2012.07.12 jkn:DE10603 failed sales should not be counted
-- 2013.03.06 knc:DE10724 Device qty not calculating correctly if All Staff selected
-- 2014.04.04 tmp:DE11701 Does not return device sales when sold to a pack. Replaced script with script
--                        from spRptSalesByDeviceSummary2 and added @MachineID parameter. 
--=============================================================================	



-- >>>>>>>>>>>>>>>>TEST<<<<<<<<<<<<<
--Declare @OperatorID	as	int,
--@StartDate	as	datetime,
--@EndDate	as	datetime,
--@StaffID    as  int,
--@Session	as	int,
--@MachineID  as  int	

--set @OperatorID = 1
--set @Session = 0
--set @StaffID = 0
--set @MachineID = 0
--set @StartDate = '1/17/2013 00:00:00'
--set @EndDate = '1/18/2013 00:00:00'

--begin
-->>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<

-- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);

-- Results table	
--create table #TempRptSalesByDeviceTotals
--(
--	productItemName		nvarchar(128),
--	deviceID			int,
--	deviceName			nvarchar(64),
--	staffIdNbr          int,            
--	staffLastName       nvarchar(64),
--	staffFirstName      nvarchar(64),
--	soldFromMachineId   int,
--	price               money,          
--	gamingDate          datetime,       
--	sessionNbr          int,            
--	itemQty				int,	       
--	electronic			money
--);
	
----
---- Populate Device Lookup Table
----
--create table #TempDevicePerReceipt
--(
--     registerReceiptID	int
--	,deviceID			int
--	,StaffID int --added DE10724
--	,SessionID int --added DE10724
--	,GamingDate datetime --added DE10724
--	,MachineID int --added DE10724
--);
	
--insert into #TempDevicePerReceipt
--    (registerReceiptID
--	,deviceID
--	,StaffID
--	,SessionID
--	,GamingDate
--	,MachineID   )
--select
--     rr.RegisterReceiptID
--    ,d.DeviceID
--    ,rr.StaffID
--   ,sp.GamingSession,
--   rr.GamingDate
--   ,rr.SoldFromMachineID   
--from RegisterReceipt rr
--    join RegisterDetail rd on rr.RegisterReceiptID=  rd.RegisterReceiptID 
--    join Device d on d.DeviceID = rr.DeviceID
--    left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
--where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
--    and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
--    and rd.VoidedRegisterReceiptID IS NULL
--    and rr.OperatorID = @OperatorID
--    and (@StaffID = 0 or rr.StaffID = @StaffID)
--    and (@Session = 0 or sp.GamingSession = @Session)
--    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )  
--    and rr.SaleSuccess = 1 --DE10603
--group by d.DeviceID, rr.RegisterReceiptID, rr.StaffID ,sp.GamingSession , rr.GamingDate , rr.SoldFromMachineID   



----		
---- Insert Electronic Rows		
----
--insert into #TempRptSalesByDeviceTotals
--(
--	productItemName,
--	deviceID,
--	deviceName,
--	staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,       
--	soldFromMachineId,
--	itemQty,	
--	electronic	
--)
--select	
--    rdi.ProductItemName,
--	d.DeviceID,
--	isnull(d.DeviceType, 'Pack'),
--	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName ,s.FirstName,                   
--	rr.SoldFromMachineID,
--	sum(rd.Quantity * rdi.Qty),--itemQty,	
--	sum(rd.Quantity * rdi.Qty * rdi.Price) --electronic,
--from RegisterReceipt rr
--	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
--	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
--	join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)
--	left join Device d on (d.DeviceID = dpr.deviceID)
--	join Staff s on rr.StaffID = s.StaffID
--where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
--	And rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)
--	and rr.SaleSuccess = 1
--	and rr.TransactionTypeID = 1
--	and rr.OperatorID = @OperatorID
--	and rdi.ProductTypeID in (1, 2, 3, 4, 5)
--	and (@Session = 0 or sp.GamingSession = @Session)
--	and rd.VoidedRegisterReceiptID is null	
--	and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic
--    and (@StaffID = 0 or rr.StaffID = @StaffID)
--    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
--group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID; 

----select * from #TempRptSalesByDeviceTotals

--insert into #TempRptSalesByDeviceTotals
--(
--	productItemName,
--	deviceID,
--	deviceName,
--	staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,       
--	soldFromMachineId,
--	itemQty,
--	electronic
--)
--select	
--    rdi.ProductItemName,
--	d.DeviceID,
--	isnull(d.DeviceType, 'Pack'),
--	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                    
--	isnull(rr.SoldFromMachineID, 0) [SoldFromMachineID],
--	sum(-1 * rd.Quantity * rdi.Qty),--itemQty,
--	sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)--electronic,
--from RegisterReceipt rr
--	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
--	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
--	join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)
--	left join Device d on (d.DeviceID = dpr.deviceID)
--	join Staff s on rr.StaffID = s.StaffID
--where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
--	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
--	and rr.SaleSuccess = 1
--	and rr.TransactionTypeID = 3 -- Return
--	and rr.OperatorID = @OperatorID
--	and rdi.ProductTypeID in (1, 2, 3, 4, 5)
--	and (@Session = 0 or sp.GamingSession = @Session)
--	and rd.VoidedRegisterReceiptID is null	
--	and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic
--    and (@StaffID = 0 or rr.StaffID = @StaffID)
--    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
--group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID; 

----select * from #TempRptSalesByDeviceTotals
----select * from #TempDevicePerReceipt
----10

--update s
--    set s.itemQty=d.ProductCount
--    from #TempRptSalesByDeviceTotals s
--    inner join (select   MachineID ,GamingDate ,SessionID ,StaffID ,deviceID, count(*) as ProductCount 
--                from #TempDevicePerReceipt
--                group by MachineID   ,GamingDate ,deviceID,StaffID,SessionID  ) d
--    on s.deviceID = d.deviceID
--    and s.staffIdNbr = d.StaffID --added 
--and s.sessionNbr = d.SessionID --added
--and s.gamingDate = d.GamingDate 
--and s.soldFromMachineId  = d.MachineID 


--select 
--    staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId
--    , isnull(Max(itemQty),0) itemQty
--    , isnull(SUM(electronic),0) electronic 
-- from #TempRptSalesByDeviceTotals
-- group by staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId
-- ORDER BY staffIdNbr,GamingDate,sessionNbr;

--return;

-- Results table	
Create table #TempRptSalesByDeviceTotals
	(
		GamingDate DateTime,
		GamingSession Int,	
		DeviceID	Int,
		DeviceSales	Money,
		DeviceCount	Int,
		StaffID		Int,
		SoldFromMachineID Int
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


INSERT INTO #TempRptSalesByDeviceTotals
(
	GamingDate,
	GamingSession,
	DeviceID,
	DeviceSales,
	DeviceCount,
	StaffID,
	SoldFromMachineID
)
SELECT	rr.GamingDate,
		sp.GamingSession,
		dpr.DeviceID,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		Case When dpr.deviceID <= 2 Then COUNT(Distinct dpr.UnitNumber) -- Count crate loaded devices
		Else Count(Distinct dpr.SoldToMachineID) End,  -- Count pack loaded devices
		rr.StaffID,
		rr.SoldFromMachineID
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
	and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )  
Group By rr.GamingDate, sp.GamingSession, rr.StaffId, dpr.DeviceID, rr.SoldFromMachineID

Select	sbd.StaffId as staffIdNbr,
		s.FirstName as staffFirstName,
		s.LastName as staffLastName,
		sbd.GamingDate as GamingDate,
		sbd.GamingSession as sessionNbr,
		sbd.DeviceID as deviceID,
		isnull(DeviceType, 'Un-Played') as deviceName,
		sbd.SoldFromMachineID,
		isnull(Sum(DeviceCount), 0) as itemQty,
		isnull(SUM(DeviceSales), 0) as electronic
From #TempRptSalesByDeviceTotals sbd 
		left join Device d on sbd.DeviceID = d.DeviceID
		join Staff s on sbd.StaffID = s.StaffID 
Where sbd.DeviceID is not null
Group By sbd.StaffID, s.FirstName, s.LastName, sbd.GamingDate, sbd.GamingSession, sbd.DeviceID, DeviceType, SoldFromMachineID
Order By sbd.StaffID, sbd.GamingDate, sbd.GamingSession, DeviceType

return;

set nocount off;

--drops
drop table #TempRptSalesByDeviceTotals

END
















GO

