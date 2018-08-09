USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpend]    Script Date: 08/22/2012 10:03:17 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerSpend]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerSpend]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpend]    Script Date: 08/22/2012 10:03:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--exec spRPTPlayerSpend 2, '8/21/2012 00:00:00','8/21/2012 00:00:00'

CREATE PROCEDURE [dbo].[spRptPlayerSpend]
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate as smallDatetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
-----------------TEST
--	declare 
--	@OperatorID	as int,
--	@StartDate	as smalldatetime,
--	@EndDate as smallDatetime

--set @OperatorID = 2
--set @StartDate = '8/21/2012 00:00:00'
--set @EndDate = '8/21/2012 00:00:00'
--------------------TEST
	
	
	SET NOCOUNT ON;
--------------------------------------OLD
--with RESULTS
--(FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed, LastVisitDate)
--as
--(
--SELECT FirstName, LastName, RR.PlayerID, PIN.OperatorID, PMC.MagneticCardNo,
--isnull(Sum(Quantity * PackagePrice), 0)  AS Spend, 
--isnull(Sum(Quantity * DiscountAmount), 0) as Discount,
--isnull(Count(Distinct(SessionPlayedID)), 0) as SessionsPlayed,
--isnull(Count(Distinct(RR.GamingDate)), 0) as DaysPlayed,
--LastVisitDate
--FROM   PlayerInformation PIN (nolock) 
--JOIN  RegisterReceipt RR (nolock) on PIN.PlayerID = RR.PlayeriD
--JOIN Player P (nolock) ON PIN.PlayerID = P.PlayerID
--Left Join PlayerMagCards PMC (nolock) on PMC.PlayerID = P.PlayerID
--JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID
--Where PIN.OperatorID = @OperatorID
--and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
--and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
--and RD.VoidedRegisterReceiptID is null
--and RR.SaleSuccess = 1
--group by  FirstName, LastName, RR.PlayerID, LastVisitDate, PIN.OperatorID, PMC.MagneticCardNo
--)
--select 
--  FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed

---- BJS 9/6/11: Added div by zero logic
--, case when DaysPlayed = 0 then 0
--  else (Spend / DaysPlayed)
--  end  [DailyAVG]

---- BJS 9/6/11: Added div by zero logic
--, case when SessionsPlayed = 0 then 0
--  else (Spend / SessionsPlayed)
--  end [SessionAVG]
--, LastVisitDate
--from RESULTS;
-------------------------------OLD

-------------------------NEW (kc/822/2012 DE10673)

select 
rr.RegisterReceiptID, rr.OriginalReceiptID,rd.VoidedRegisterReceiptID ,
 FirstName, LastName, rr.PlayerID, pin.OperatorID, pmc.MagneticCardNo 
,Quantity, PackagePrice, DiscountAmount, SessionPlayedID, rr.GamingDate ,LastVisitDate
-- FirstName, LastName, RR.PlayerID, PIN.OperatorID, PMC.MagneticCardNo,
--isnull(Sum(Quantity * PackagePrice), 0)  AS Spend, 
--isnull(Sum(Quantity * DiscountAmount), 0) as Discount,
--isnull(Count(Distinct(SessionPlayedID)), 0) as SessionsPlayed,
--isnull(Count(Distinct(RR.GamingDate)), 0) as DaysPlayed,
--LastVisitDate
 into #a
from PlayerInformation PIN
JOIN  RegisterReceipt RR (nolock) on PIN.PlayerID = RR.PlayeriD and PIN.OperatorID = rr.OperatorID 
JOIN Player P (nolock) ON PIN.PlayerID = P.PlayerID
Left Join PlayerMagCards PMC (nolock) on PMC.PlayerID = P.PlayerID
left join RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID 
where /*pin.PlayerID in (5)
and*/ pin.OperatorID = @OperatorID
and RR.SaleSuccess = 1
and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
--and RD.VoidedRegisterReceiptID is null
and RR.SaleSuccess = 1
--group by  FirstName, LastName, RR.PlayerID, LastVisitDate, PIN.OperatorID, PMC.MagneticCardNo
--order by pin.OperatorID asc




;with RESULTS as
--(FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed, LastVisitDate)
(
select 
FirstName, LastName,PlayerID,OperatorID ,MagneticCardNo, Quantity, PackagePrice, DiscountAmount,SessionPlayedID
,GamingDate,LastVisitDate      
from #a 
where VoidedRegisterReceiptID is not null or OriginalReceiptID is null
union 
select 
a.FirstName, a.LastName,a.PlayerID,a.OperatorID,a.MagneticCardNo, b.Quantity, b.PackagePrice * -1 as  PackagePrice , a.DiscountAmount,a.SessionPlayedID
,b.GamingDate ,a.LastVisitDate 
from #a a join #a b on a.RegisterReceiptID = b.VoidedRegisterReceiptID ),
result2 as 
(select FirstName, LastName, PlayerID, OperatorID, MagneticCardNo,
ISNULL(sum(Quantity * PackagePrice),0) as spend,
isnull(Sum(Quantity * DiscountAmount), 0) as Discount,
isnull(Count(Distinct(SessionPlayedID)), 0) as SessionsPlayed,
isnull(Count(Distinct(GamingDate)), 0) as DaysPlayed,
LastVisitDate
 from RESULTS
 group by  FirstName, LastName, PlayerID, LastVisitDate, OperatorID, MagneticCardNo )
 select 
  FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed

, case when DaysPlayed = 0 then 0
  else (Spend / DaysPlayed)
  end  [DailyAVG]

, case when SessionsPlayed = 0 then 0
  else (Spend / SessionsPlayed)
  end [SessionAVG]
, LastVisitDate
from RESULT2;
 




drop table #a 


END;





GO


