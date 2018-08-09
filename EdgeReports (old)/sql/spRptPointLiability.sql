USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPointLiability]    Script Date: 05/03/2012 09:05:15 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPointLiability]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPointLiability]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPointLiability]    Script Date: 05/03/2012 09:05:15 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptPointLiability] 
	@OperatorID as int,
	@StartDate as smalldatetime

	
AS
SET NOCOUNT ON
----------------------------------------
--TEST
--declare @OperatorID int
----declare @Startdate smalldatetime
--declare @StartDate smalldatetime
----declare @EndDate smalldatetime
----select * from RegisterReceipt 

--set @OperatorID = 1
--set @StartDate = '2012-04-04 00:00:00'
----set @EndDate = '2012-04-04 14:48:13'
----------------------------------------------




DECLARE @OperatorsShareStr varchar(30)		
SELECT @OperatorsShareStr = (SELECT SettingValue FROM GlobalSettings WHERE GlobalSettingID = 180)

declare @TableA table
(LastName varchar(50),
FirstName varchar (50),
OperatorID int,
PointsBalance money,
PointBalancesID int)


IF (@OperatorsShareStr LIKE '%t%')
BEGIN
insert into @TableA 
	Select DISTINCT LastName, FirstName, OperatorID = @OperatorID,
		PointsBalance = pb.pbPointsBalance,pb.pbPointBalancesID 
	From PlayerInformation PIN (nolock)
	Join Player P (nolock) on PIN.PlayerID = P.PlayerID
	join PointBalances pb(nolock) on PIN.PointBalancesID = pb.pbPointBalancesID
	and pbPointsBalance > 0
END
ELSE
BEGIN
insert into @TableA 
	Select LastName, FirstName, PIN.OperatorID,
		PointsBalance = pbPointsBalance, pb.pbPointBalancesID
	From PlayerInformation PIN (nolock)
	Join Player P (nolock) on PIN.PlayerID = P.PlayerID
	join PointBalances pb(nolock) on PIN.PointBalancesID = pb.pbPointBalancesID
	Where PIN.OperatorID = @OperatorID
	and pb.pbPointsBalance > 0
	
	
END

select 

rr.PreSalePoints, rr.AmountTendered , 
rd.Quantity, rd.DiscountAmount, rd.DiscountPtsPerDollar ,
rd.PackagePrice, rd.TotalPtsRedeemed , rd.TotalPtsEarned ,  
p.FirstName, rr.DTStamp, rr.GamingDate ,  
pli.PointBalancesID,rr.OperatorID ,
p.playerID
into #a
from RegisterReceipt rr
join Player p on p.PlayerID = rr.PlayerID 
join PlayerInformation pli on pli.PlayerID = p.PlayerID 
join RegisterDetail rd on rd.RegisterReceiptID = rr.RegisterReceiptID 
where rr.PreSalePoints is not null
and rd.VoidedRegisterReceiptID is null
and rr.SaleSuccess = 1
and cast(CONVERT(varchar(12),rr.DTStamp , 101)as smalldatetime)  >= '01/01/1900 00:00:00' 
and cast(CONVERT(varchar(12),rr.DTStamp , 101)as smalldatetime) <= cast(CONVERT(varchar(12),@StartDate, 101)as smalldatetime)
--and  ( CONVERT(varchar(100),rr.DTStamp , 101)   >=   CONVERT(varchar(100),@Startdate , 101) and
--		CONVERT(varchar(100),rr.DTStamp , 101)   <=  CONVERT(varchar(100),@EndDate , 101))
     
select 
--IsNull(SUM(ISNULL(a.TotalPtsEarned, 0) * a.Quantity) + SUM(ISNULL(a.DiscountPtsPerDollar, 0) * a.Quantity * ISNULL (a.DiscountAmount, 0)), 0)   
---SUM(TotalPtsRedeemed*Quantity)as Points ,
isnull(SUM(isnull(a.TotalPtsEarned,0)*a.Quantity ),0)
+ SUM(ISNULL(a.DiscountPtsPerDollar, 0) * a.Quantity * ISNULL (a.DiscountAmount, 0))
-SUM(isnull(TotalPtsRedeemed,0)*Quantity) as Points,
a.PlayerID ,
 B.LastName, a.FirstName ,
a.PointBalancesID ,
a.OperatorID, b.PointsBalance   
into #b 
from #a a left join @TableA b on b.PointBalancesID = a.PointBalancesID 
group by a.FirstName, a.PointBalancesID , a.OperatorID, b.PointsBalance, B.LastName, a.PlayerID
order by a.PlayerID 

declare @a  money


select b.Points,b.PlayerID, b.LastName, B.FirstName ,b.PointBalancesID ,b.OperatorID ,b.PointsBalance ,c.PreSalePoints ,isnull(b.Points,0) + c.PreSalePoints   as RPoints
--b.PlayerID,b.Points,c.PreSalePoints  ,c.PreSalePoints + c.PreSalePoints as PointA   
into #c
from #b b 
join (select rd.RegisterDetailID,
p.PlayerID , rr.PreSalePoints 
from RegisterReceipt rr
join Player p on p.PlayerID = rr.PlayerID 
join PlayerInformation pli on pli.PlayerID = p.PlayerID 
join RegisterDetail rd on rd.RegisterReceiptID = rr.RegisterReceiptID 
join(
select min(rd.RegisterDetailID) as RegisterDetailID,
p.PlayerID 
from RegisterReceipt rr
join Player p on p.PlayerID = rr.PlayerID 
join PlayerInformation pli on pli.PlayerID = p.PlayerID 
join RegisterDetail rd on rd.RegisterReceiptID = rr.RegisterReceiptID 
where  
rr.PreSalePoints is not null 
--and rd.VoidedRegisterReceiptID is null
and rr.SaleSuccess = 1
group by p.PlayerID ) a on a.PlayerID = p.PlayerID and a.RegisterDetailID = rd.RegisterDetailID

where  
rr.PreSalePoints is not null 
and rd.VoidedRegisterReceiptID is null
and rr.SaleSuccess = 1) c on c.PlayerID = b.PlayerID order by b.PlayerID 

select *
/*nullif(RPoints, PointsBalance),*/
 from #c 
 --order by LastName asc
--where nullif(RPoints, PointsBalance) is not null



drop table #a
drop table #b
drop table #c 



SET NOCOUNT OFF





GO


