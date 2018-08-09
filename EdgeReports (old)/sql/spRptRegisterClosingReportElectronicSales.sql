USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportElectronicSales]    Script Date: 07/12/2012 08:37:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportElectronicSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportElectronicSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportElectronicSales]    Script Date: 07/12/2012 08:37:27 ******/
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

as
--=============================================================================	
--  2012.07.12 jkn:DE10603 failed sales should not be counted
--=============================================================================	
begin
-- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);

-- Results table	
create table #TempRptSalesByDeviceTotals
(
	productItemName		nvarchar(128),
	deviceID			int,
	deviceName			nvarchar(64),
	staffIdNbr          int,            
	staffLastName       nvarchar(64),
	staffFirstName      nvarchar(64),
	soldFromMachineId   int,
	price               money,          
	gamingDate          datetime,       
	sessionNbr          int,            
	itemQty				int,	       
	electronic			money
);
	
--
-- Populate Device Lookup Table
--
create table #TempDevicePerReceipt
(
     registerReceiptID	int
	,deviceID			int
);
	
insert into #TempDevicePerReceipt
    (registerReceiptID
	,deviceID)
select
     rr.RegisterReceiptID
    ,d.DeviceID
from RegisterReceipt rr
    join RegisterDetail rd on rr.RegisterReceiptID=  rd.RegisterReceiptID 
    join Device d on d.DeviceID = rr.DeviceID
    left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
    and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
    and rd.VoidedRegisterReceiptID IS NULL
    and rr.OperatorID = @OperatorID
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and (@Session = 0 or sp.GamingSession = @Session)
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )  
    and rr.SaleSuccess = 1 --DE10603
group by d.DeviceID, rr.RegisterReceiptID

--		
-- Insert Electronic Rows		
--
insert into #TempRptSalesByDeviceTotals
(
	productItemName,
	deviceID,
	deviceName,
	staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,       
	soldFromMachineId,
	itemQty,	
	electronic	
)
select	
    rdi.ProductItemName,
	d.DeviceID,
	isnull(d.DeviceType, 'Pack'),
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName ,s.FirstName,                   
	rr.SoldFromMachineID,
	sum(rd.Quantity * rdi.Qty),--itemQty,	
	sum(rd.Quantity * rdi.Qty * rdi.Price) --electronic,
from RegisterReceipt rr
	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
	join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)
	left join Device d on (d.DeviceID = dpr.deviceID)
	join Staff s on rr.StaffID = s.StaffID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	and rdi.ProductTypeID in (1, 2, 3, 4, 5)
	and (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID is null	
	and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID; 

insert into #TempRptSalesByDeviceTotals
(
	productItemName,
	deviceID,
	deviceName,
	staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,       
	soldFromMachineId,
	itemQty,
	electronic
)
select	
    rdi.ProductItemName,
	d.DeviceID,
	isnull(d.DeviceType, 'Pack'),
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                    
	isnull(rr.SoldFromMachineID, 0) [SoldFromMachineID],
	sum(-1 * rd.Quantity * rdi.Qty),--itemQty,
	sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)--electronic,
from RegisterReceipt rr
	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
	join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)
	left join Device d on (d.DeviceID = dpr.deviceID)
	join Staff s on rr.StaffID = s.StaffID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	and rdi.ProductTypeID in (1, 2, 3, 4, 5)
	and (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID is null	
	and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID)
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID; 

update s
    set s.itemQty=d.ProductCount
    from #TempRptSalesByDeviceTotals s
    inner join (select  deviceID, count(*) as ProductCount 
                from #TempDevicePerReceipt
                group by deviceID) d
    on s.deviceID = d.deviceID

select 
    staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId
    , isnull(Max(itemQty),0) itemQty
    , isnull(SUM(electronic),0) electronic 
 from #TempRptSalesByDeviceTotals
 group by staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId
 ORDER BY staffIdNbr,GamingDate,sessionNbr;

return;

--drops
drop table #TempRptSalesByDeviceTotals
drop table #TempDevicePerReceipt

END


GO

