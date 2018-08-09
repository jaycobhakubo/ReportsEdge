USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubElectronicBingo]    Script Date: 03/07/2014 15:18:55 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubElectronicBingo]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubElectronicBingo]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubElectronicBingo]    Script Date: 03/07/2014 15:18:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE proc [dbo].[spRptSubElectronicBingo]  

---- =============================================  
---- Author: bhendrix  
---- Description: 2012/01/20 Stored procedure  
---- re-written to be more acturate and only  
---- report data relavent for this report. 
---- 2014.03.07 tmp: US3103 Add the Ted-E to the where condition device id equals.  
---- =============================================  
--declare  
 @OperatorID AS INT,  
 @StartDate AS DATETIME,  
-- @EndDate AS DATETIME,  
 @Session AS INT  
   
   
 --set @OperatorID = 1  
 --set @StartDate = '01/09/2012 00:00:00'  
 --set @EndDate = '01/09/2012 00:00:00'  
 --set @Session = 1  
   
 --@ProductGroupID as int  
as  
begin  
 set nocount on;  
 -- FIX US1902  
 -- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...  
 --declare @groupName nvarchar(64); --set @groupName = 'All Groups';  
 --select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;  
   declare @EndDate datetime
 -- truncate the dates  
 set @StartDate = datediff(day, 0, @StartDate);  
 set @EndDate = datediff(day, -1, @StartDate);  
   
 -- Create a lookup to get device type for each receipt  
 declare @DevicePerReceiptSummary table  
 (  
  gamingDate datetime,  
  gamingSession int,  
  sessionPlayedId int,  
  receiptId int,  
  deviceId int,  
  deviceNumber int  
 );  
   
 insert into @DevicePerReceiptSummary(  
  gamingDate,  
  gamingSession,  
  sessionPlayedId,  
  receiptId,  
  deviceId,  
  deviceNumber)  
 select sp.GamingDate,  
  sp.GamingSession,  
  rd.SessionPlayedID,  
  rr.RegisterReceiptID,  
  ul.ulDeviceID,  
  case when ul.ulDeviceID <= 2 then case when ul.ulUnitNumber = 0 then null else ul.ulUnitNumber end  
   else ul.ulSoldToMachineID end  
 from RegisterReceipt rr  
  join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)  
  join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)  
  join UnlockLog ul on (ulID = (select top 1 ulID  
   from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptID  
    and ulPackLoginAssignDate is not null  
    and ulDeviceID is not null  
   order by ulPackLoginAssignDate desc))  
  left join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)  
 where rr.GamingDate >= @StartDate  
  and rr.GamingDate < @EndDate  
  and rr.SaleSuccess = 1  
  and rr.TransactionTypeID = 1  
  and rr.OperatorID = @OperatorID  
  and rd.VoidedRegisterReceiptID is null  
  and (@Session = 0 or sp.GamingSession = @Session)  
  and (rdi.ProductTypeID = 5 or (rdi.ProductTypeID in (1, 2, 3, 4) and rdi.CardMediaID = 1))  
  --and (@ProductGroupID = 0 or rdi.GroupName = @groupName)  
  -- Traveler, Tracker, Explorer 2, Fixed Base, Traveler II, Ted-E  
  and ul.ulDeviceID in (1, 2, 3, 4, 14, 17)  
   
 declare @Results table  
 (  
  deviceId int,  
  units int,  
  unitsFee money  
 );  
   
 insert into @Results (drs.deviceId, units, unitsFee)  
 select drs.deviceId, count(distinct drs.deviceNumber), 0.00  
 from @DevicePerReceiptSummary drs  
  left join SessionPlayed sp on (drs.sessionPlayedId = sp.SessionPlayedID)  
 -- Grouping by gaming date and gaming session to match spRptSalesByDeviceSummary counts  
 group by sp.GamingDate, sp.GamingSession, drs.deviceId  
  --drs.sessionPlayedID,  
  --drs.receiptId,  
  --drs.deviceId;  
    
 update @Results  
 set unitsFee = r.units * isnull(ddf.ddfDeviceFee, 0)  
 from @Results r  
  left join DistributorDeviceFees ddf on (ddf.ddfDeviceId = r.DeviceId)  
 where ddf.ddfOperatorID = @OperatorID  
  and ddf.ddfDeviceID = r.DeviceID  
  and ddf.ddfDistDeviceFeeTypeID = 1 -- per use device fee  
  and r.units >= ddf.ddfMinRange  
  and r.units <= ddf.ddfMaxRange  
    
 select isnull(sum(units), 0) as UnitsSold, isnull(sum(unitsFee), 0) as TotFee  
 from @Results  
end  
  











GO

