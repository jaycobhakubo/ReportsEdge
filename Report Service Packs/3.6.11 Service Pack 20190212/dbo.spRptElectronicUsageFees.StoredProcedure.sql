USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicUsageFees]    Script Date: 2/14/2019 1:16:44 PM ******/
DROP PROCEDURE [dbo].[spRptElectronicUsageFees]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicUsageFees]    Script Date: 2/14/2019 1:16:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptElectronicUsageFees]
-- =============================================
-- Author:		Satish Anju
-- Description:	Electronic Usage Fees.
--
-- 2011.12.29 SA: New report
-- 2012.02.10 SA:DE10074,DE10072,DE10076
-- 20150925(knc): Add coupon sale.
-- 2017.12.13 jkn Removed references to the History db
-- 2018.05.22 tmp: US5575 Added support for Presales
-- 2018.05.22 tmp: Updated to get the device fee charged for the session instead of for the transaction.
-- 2018.05.22 tmp: Do not include transactions where the device fee is 0.
-- 2019.02.12 tmp: Complete re-write. Updated to get the device fee when charging for the entire order or per session.
--                 If sold to a device and there is not a device fee charged then it updates the sales for the device type sold to.
-- =============================================
--declare 
@OperatorID as int,
@StartDate as datetime,
@EndDate as datetime,
@Session as int

--set @OperatorID = 1
--set @StartDate = '10/6/2015 00:00:00'
--set @EndDate = '10/6/2015 00:00:00'
--set @Session = 7

as
begin
----create table #ElectronicFee
----(
----RegisterReceiptID  int,
----OriginalRegisterReceiptID  int,
----ulDeviceID  int,
----RRDeviceID int,
----DeviceType  nvarchar(32),
----NoOfUnits  int,
----DeviceFee  money,
----GamingSession  int,
----SalesLessFee  money,
----GamingDate datetime,
----TransactionNumber int 
----)


----; with ElectronicFee
----(
----GamingDate,
----RegisterReceiptID ,
----RRDeviceID  ,
----NoOfUnits ,
----DeviceType,
----DeviceFee ,
----GamingSession ,
----SalesLessFee
----)    
----as
----(
----select 
---- --      RR.GamingDate
----	rd.PlayGamingDate
----	,RR.RegisterReceiptID
----	,RR.DeviceID
----	,1 as #Units
----	,isnull(D.DeviceType, 'Pack')
----	--,RR.DeviceFee
----	, isnull(rd.DeviceFee, 0)
------	, sum(isnull(rd.DeviceFee, 0))
------  ,SP.GamingSession
----	,rd.PlayGamingSession
----	,(sum(RDI.Price * RD.Quantity * RDI.Qty )) --+ sum(isnull(cpn.CouponSales,0))
----from RegisterReceipt RR
----	left join Device D on D.DeviceID=RR.DeviceID   
----	left join RegisterDetail RD on RR.RegisterReceiptID=RD.RegisterReceiptID
---- --left join (select distinct SessionPlayedID, GamingSession, GamingDate	
----	--		from SessionPlayed) as sp
----	--		on RD.SessionPlayedID = sp.SessionPlayedID
---- left join RegisterDetailItems RDI on RDI.RegisterDetailID=RD.RegisterDetailID
---- --Get coupon sales
---- --left join (select 	TransactionNumber, CouponSales from  dbo.FindCouponSalesByTransaction(@OperatorID, @StartDate, @EndDate, @Session)) cpn on cpn.TransactionNumber = rr.TransactionNumber
----where  
----	--RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
----	--and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
----	rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
----	and Rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
----	and RDI.CardMediaID=1
----	and RR.SaleSuccess=1
----	and RR.TransactionTypeID=1
----	and RD.VoidedRegisterReceiptID is null    --added for not including voided sales in the report
----	and RR.OperatorID=@OperatorID
----	--and (@Session = 0 or SP.GamingSession = @Session)
----	and (@Session = 0 or rd.PlayGamingSession = @Session)
------	and rd.DeviceFee <> 0
---- group by 
----       --RR.GamingDate
----	rd.PlayGamingDate
----	,RR.RegisterReceiptID
----	,RR.DeviceID
----	,D.DeviceType
----	--,rr.DeviceFee
----	,rd.DeviceFee
----	--,SP.GamingSession
----	,rd.PlayGamingSession
----)
----, Coupon
----as
----(
----	select rr.RegisterReceiptID
----		, isnull(sum(rd.Quantity * rd.PackagePrice),0) as CoupontSales 
----	from RegisterReceipt RR
----		left join RegisterDetail RD on RR.RegisterReceiptID=RD.RegisterReceiptID
----		left join (	select distinct SessionPlayedID, GamingSession, GamingDate	
----					from SessionPlayed) as sp on RD.SessionPlayedID = sp.SessionPlayedID
----		join CompAward ca on ca.CompAwardID = rd.CompAwardID -- I only want coupon
----		join Comps c on c.CompID = ca.CompID
----	where rd.CompAwardID is not null 
----		and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
----		and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
----		and RR.SaleSuccess=1
----		and RR.TransactionTypeID=1
----		and RD.VoidedRegisterReceiptID is null    --added for not including voided sales in the report
----		and RR.OperatorID=@OperatorID
----		and (@Session = 0 or SP.GamingSession = @Session)
----	group by rr.RegisterReceiptID
----)  


----Insert into #ElectronicFee
----(
----	GamingDate,
----	RegisterReceiptID ,
----	RRDeviceID  ,
----	NoOfUnits ,
----	DeviceType,
----	DeviceFee ,
----	GamingSession ,
----	SalesLessFee
----) 
----select 
----	GamingDate,
----	ef.RegisterReceiptID ,
----	RRDeviceID  ,
----	NoOfUnits ,
----	DeviceType,
----	DeviceFee ,
----	GamingSession ,
----	SalesLessFee --, isnull(ca.CoupontSales,0)
----from ElectronicFee ef --left join Coupon ca on ca.RegisterReceiptID = ef.RegisterReceiptID ;

--select T.GamingDate
--	,T.DeviceType
--	,sum(NoOfUnits) NoOfUnits
--	,DeviceFee
--	,sum(SalesLessFee)SalesLessFee
--	,T.GamingSession 
--from #ElectronicFee T
--group by GamingDate,DeviceType,DeviceFee,GamingSession
--drop table #ElectronicFee

declare @DeviceFee table
(
	GamingDate			datetime
	, GamingSession		int
	, DeviceID			int
	, NoOfUnits			int
	, DeviceFee			money
	, SalesLessFee		money
)

declare @DeviceFeesNbrSessions table
(
	RegisterReceiptID int
	, NbrSessions int
)
insert into @DeviceFeesNbrSessions
(
	RegisterReceiptID
	, NbrSessions
)
select	rr.RegisterReceiptID
		, count(rd.DeviceFee)
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
where	rr.OperatorID = @OperatorID
		and rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and Rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rr.TransactionTypeID=1
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.DeviceFee is not null
group by rr.RegisterReceiptID

insert into @DeviceFee
(
	GamingDate
	, GamingSession
	, DeviceID
	, NoOfUnits
	, DeviceFee
	, SalesLessFee
)	
select	rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.DeviceID
		, count(distinct rr.RegisterReceiptID)
		, rr.DeviceFee
		, (sum(RDI.Price * RD.Quantity * RDI.Qty ))
from	@DeviceFeesNbrSessions as DF
		join RegisterReceipt rr on DF.RegisterReceiptID = rr.RegisterReceiptID and DF.NbrSessions = 1
		left join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
where	rdi.CardMediaID=1
group by rd.PlayGamingDate
	, rd.PlayGamingSession
	, rr.DeviceID
	, rr.DeviceFee;

insert into @DeviceFee
(
	GamingDate
	, GamingSession
	, DeviceID
	, NoOfUnits
	, DeviceFee
	, SalesLessFee
)	
select	rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.DeviceID
		, count(distinct rr.RegisterReceiptID)
		, isnull(rd.DeviceFee, 0)
		, (sum(RDI.Price * RD.Quantity * RDI.Qty ))
from	@DeviceFeesNbrSessions as DF
		join RegisterReceipt rr on DF.RegisterReceiptID = rr.RegisterReceiptID and DF.NbrSessions > 1
		left join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
where	rdi.CardMediaID=1
group by rd.PlayGamingDate
	, rd.PlayGamingSession
	, rr.DeviceID
	, rd.DeviceFee;

update d
set SalesLessFee = SalesLessFee + 

				isnull((
						select  (sum(RDI.Price * RD.Quantity * RDI.Qty ))
						from	@DeviceFeesNbrSessions as DF
								join RegisterReceipt rr on DF.RegisterReceiptID = rr.RegisterReceiptID and DF.NbrSessions = 0
								left join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
								left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
						where	rdi.CardMediaID=1
								and d.GamingDate = rd.PlayGamingDate
								and d.GamingSession = rd.PlayGamingSession
								and d.DeviceID = rr.DeviceID
						group by rd.PlayGamingDate
							, rd.PlayGamingSession
							, rr.DeviceID
						), 0)
from @DeviceFee d


select	df.GamingDate
		, d.DeviceType
		, df.NoOfUnits
		, df.DeviceFee
		, df.SalesLessFee
		, df.GamingSession 
from	@DeviceFee df
		join Device d on df.DeviceID = d.DeviceID
order by GamingDate,
		GamingSession
--group by GamingDate,DeviceType,DeviceFee,GamingSession


end 

GO

