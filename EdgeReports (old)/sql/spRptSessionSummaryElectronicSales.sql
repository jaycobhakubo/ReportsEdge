USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryElectronicSales]    Script Date: 02/03/2012 13:24:37 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummaryElectronicSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummaryElectronicSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryElectronicSales]    Script Date: 02/03/2012 13:24:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptSessionSummaryElectronicSales]
(
    @OperatorID	int,
    @GameDate datetime,
    @Session int
)
as
begin
	set nocount on;

	-- Create a lookup to get device type for each receipt
	declare @DevicePerReceiptSummary table
	(
		gamingDate datetime,
		gamingSession int,
		sessionPlayedId int,
		receiptId int,
		detailid int,
		itemid int,
		deviceId int,
		deviceName nvarchar(64),
		deviceNumber int,
		sales money,
		transTypeId int,
		transType nvarchar(64)
	);
	
	insert into @DevicePerReceiptSummary(
		gamingDate,
		gamingSession,
		sessionPlayedId,
		receiptId,
		deviceId,
		deviceName,
		deviceNumber,
		sales,
		transTypeId,
		transType)
	select sp.GamingDate,
		sp.GamingSession,
		rd.SessionPlayedID,
		rr.RegisterReceiptID,
		ul.ulDeviceID,
		d.DeviceType,
		case when ul.ulDeviceID <= 2 then case when ul.ulUnitNumber = 0 then null else ul.ulUnitNumber end
			else ul.ulSoldToMachineID end,
		rd.Quantity * rdi.Qty * case when rr.TransactionTypeID = 1 then rdi.Price 
			else -rdi.Price end,
		rr.TransactionTypeID,
		case rr.TransactionTypeID when 1 then 'Sale' else 'Return' end
	from RegisterReceipt rr
		join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
		join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
		left join UnlockLog ul on (ulID = (select top 1 ulID
			from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptID
				and ulPackLoginAssignDate is not null
				--and ulDeviceID is not null
			order by ulPackLoginAssignDate desc))
		left join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
		left join Device d on (d.DeviceID = ul.ulDeviceID)
	where rr.GamingDate = @GameDate
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID in (1, 3) -- Sales, Return
		and rr.OperatorID = @OperatorID
		and rd.VoidedRegisterReceiptID is null
		and (@Session = 0 or sp.GamingSession = @Session)
		and (rdi.ProductTypeID = 5 or (rdi.ProductTypeID in (1, 2, 3, 4) and rdi.CardMediaID = 1))
		-- Pack, or Traveler, Tracker, Explorer, Fixed Base, Traveler II
		and (ul.ulDeviceID is null or ul.ulDeviceID in (1, 2, 3, 4, 14))
		
	-- DEBUG
	--select * from @DevicePerReceiptSummary order by receiptid
	
	declare @Results table
	(
		deviceName nvarchar(64),
		units int,
		sales money
	);
	
	-- Don't worry about counting returns, because electronic items cannot be returned.
	insert into @Results (drs.deviceName, units, sales)
	select drs.deviceName,
		case when drs.deviceName is null then count(distinct drs.receiptId)
				else count(distinct drs.deviceNumber) end,
			sum(drs.sales)
	from @DevicePerReceiptSummary drs
	-- Grouping by gaming date and gaming session to match spRptSalesByDeviceSummary counts
	group by drs.gamingDate, drs.GamingSession, drs.transTypeId, drs.deviceName;
	
	-- DEBUG
	--select * from @Results;
	
	select isnull(deviceName, N'Pack') as deviceName, sum(units) as itemQty, sum(sales) as electronic
	from @Results
	group by deviceName
end;


GO


