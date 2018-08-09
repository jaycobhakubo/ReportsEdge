USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicUsageFees]    Script Date: 02/10/2012 09:52:58 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicUsageFees]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicUsageFees]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicUsageFees]    Script Date: 02/10/2012 09:52:58 ******/
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
-- =============================================
@OperatorID as int,
@StartDate as datetime,
@EndDate as datetime,
@Session as int

as
begin
create table #ElectronicFee
(
RegisterReceiptID  int,
OriginalRegisterReceiptID  int,
ulDeviceID  int,
RRDeviceID int,
DeviceType  nvarchar(32),
NoOfUnits  int,
DeviceFee  money,
GamingSession  int,
SalesLessFee  money,
GamingDate datetime,
TransactionNumber int 
)


; with ElectronicFee
(
GamingDate,
RegisterReceiptID ,
RRDeviceID  ,
NoOfUnits ,
DeviceType,
DeviceFee ,
GamingSession ,
SalesLessFee
)    
as
(
select 
       RR.GamingDate
      ,RR.RegisterReceiptID
      ,RR.DeviceID
      ,1 as #Units
      ,D.DeviceType
      ,RR.DeviceFee
      ,SP.GamingSession
        ,(sum(RDI.Price * RD.Quantity * RDI.Qty )) --+ sum(isnull(cpn.CouponSales,0))
      
 from RegisterReceipt RR
 left join Device D on D.DeviceID=RR.DeviceID   
 left join RegisterDetail RD on RR.RegisterReceiptID=RD.RegisterReceiptID
 left join (select distinct SessionPlayedID, GamingSession, GamingDate	
			from SessionPlayed) as sp
			on RD.SessionPlayedID = sp.SessionPlayedID
 left join (select distinct SessionPlayedID, GamingSession, gamingdate	
		    from History.dbo.SessionPlayed ) as hsp
			on RD.SessionPlayedID = hsp.SessionPlayedID
 left join RegisterDetailItems RDI on RDI.RegisterDetailID=RD.RegisterDetailID
 --Get coupon sales
 --left join (select 	TransactionNumber, CouponSales from  dbo.FindCouponSalesByTransaction(@OperatorID, @StartDate, @EndDate, @Session)) cpn on cpn.TransactionNumber = rr.TransactionNumber
 where  RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
 and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
 and RDI.CardMediaID=1
 and RR.SaleSuccess=1
 and RR.TransactionTypeID=1
 and RD.VoidedRegisterReceiptID is null    --added for not including voided sales in the report
 and RR.OperatorID=@OperatorID
 and (@Session = 0 or SP.GamingSession = @Session)
 group by 
       RR.GamingDate
      ,RR.RegisterReceiptID
      ,RR.DeviceID
      ,D.DeviceType
      ,RR.DeviceFee
      ,SP.GamingSession)
, Coupon
as
(
	select rr.RegisterReceiptID, sum(rd.Quantity * rd.PackagePrice) as CoupontSales from RegisterReceipt RR
	 left join RegisterDetail RD on RR.RegisterReceiptID=RD.RegisterReceiptID
	  left join (select distinct SessionPlayedID, GamingSession, GamingDate	
				from SessionPlayed) as sp on RD.SessionPlayedID = sp.SessionPlayedID
				 join CompAward ca on ca.CompAwardID = rd.CompAwardID -- I only want coupon
				 join Comps c on c.CompID = ca.CompID
	where rd.CompAwardID is not null 
	and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	 and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	 and RR.SaleSuccess=1
	 and RR.TransactionTypeID=1
	 and RD.VoidedRegisterReceiptID is null    --added for not including voided sales in the report
	 and RR.OperatorID=@OperatorID
	 and (@Session = 0 or SP.GamingSession = @Session)
	 group by rr.RegisterReceiptID
)  

    
    Insert into #ElectronicFee
(
GamingDate,
RegisterReceiptID ,
RRDeviceID  ,
NoOfUnits ,
DeviceType,
DeviceFee ,
GamingSession ,
SalesLessFee
) 
select 
GamingDate,
ef.RegisterReceiptID ,
RRDeviceID  ,
NoOfUnits ,
DeviceType,
DeviceFee ,
GamingSession ,
SalesLessFee + ca.CoupontSales  
      from ElectronicFee ef left join Coupon ca on ca.RegisterReceiptID = ef.RegisterReceiptID ;

            
select T.GamingDate,T.DeviceType,sum(NoOfUnits) NoOfUnits,DeviceFee,sum(SalesLessFee)SalesLessFee,T.GamingSession from #ElectronicFee T
group by GamingDate,DeviceType,DeviceFee,GamingSession
drop table #ElectronicFee

end 







GO


