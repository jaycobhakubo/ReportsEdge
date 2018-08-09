USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan_Electronics]    Script Date: 02/03/2012 13:21:20 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSalesMichigan_Electronics]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSalesMichigan_Electronics]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan_Electronics]    Script Date: 02/03/2012 13:21:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptDoorSalesMichigan_Electronics] 
-- =============================================
-- Author: bhendrix
-- Description: 2012/01/20 Stored procedure
-- re-written to be more acturate and only
-- report data relavent for this report.
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int
as
begin
	set nocount on;
	-- FIX US1902
	-- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...
	declare @groupName nvarchar(64); --set @groupName = 'All Groups';
	select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;
	
	-- truncate the dates
	set @StartDate = datediff(day, 0, @StartDate);
	set @EndDate = datediff(day, -1, @EndDate);
	
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
		and (@ProductGroupID = 0 or rdi.GroupName = @groupName)
		-- Traveler, Tracker, Explorer, Fixed Base, Traveler II
		and ul.ulDeviceID in (1, 2, 3, 4, 14)
	
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


