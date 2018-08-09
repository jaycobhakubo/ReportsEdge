USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendSummary]    Script Date: 03/01/2013 08:48:50 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerSpendSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerSpendSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendSummary]    Script Date: 03/01/2013 08:48:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE proc [dbo].[spRptPlayerSpendSummary]
(
--declare 
@OperatorID int, 
@StartDate datetime, 
@EndDate datetime, 
@PlayerID int

--set @OperatorID =1  
--set @StartDate = '9/25/2015 00:00:00' 
--set @EndDate = '9/25/2015 00:00:00'
--set @PlayerID = 5

)
--set @OperatorID =1  
--set @StartDate = '9/18/2015 00:00:00' 
--set @EndDate = '9/18/2015 00:00:00'
--set @PlayerID = 1
--)
 -- ===============================
 --Author: Karlo Camacho
 --Date: 2/15/2013
 --Description: Store procedure that will be use on PlayerSpendSummary Report.
 --NOTE: This script is base on RegisterClosingReport 
 --20150918(knc) : Add coupon sales.

 -- ===============================
as     



declare @SalesActivity table
(
GamingDate datetime,
GamingSession int,
ReceiptNumber int,
PlayerID int,
Paper money default(0),
Electronics money default(0),
BingoOther money default(0),
PullTab money default(0),
ConsNMdse money default(0),
DeviceFees money default(0),
Discounts money default(0),
Coupon money default(0),
Taxes money default(0)
)

--CONSNNMDSE

insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,ConsNMdse)  
select rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when   1 then     SUM(rd.Quantity * rdi.Qty * rdi.Price)
when  3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end
FROM RegisterReceipt rr      
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)      
LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)      
join Staff s on rr.StaffID = s.StaffID      
left Join Player p on p.PlayerID = rr.PlayerID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID in (1,3)      
and rr.OperatorID = @OperatorID      
AND (rdi.ProductTypeID = 7  or rdi.ProductTypeID = 6)          
and rd.VoidedRegisterReceiptID IS NULL      
AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)   
And (p.PlayerID = @PlayerID or @PlayerID = 0)           
GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID
  
--ELECTRONICS

insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,Electronics) 
select rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when   1 then     SUM(rd.Quantity * rdi.Qty * rdi.Price)
when  3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end
FROM RegisterReceipt rr      
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)      
LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)           
join Staff s on rr.StaffID = s.StaffID      
left Join Player p on p.PlayerID = rr.PlayerID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID in (1,3)      
and rr.OperatorID = @OperatorID      
AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)            
and rd.VoidedRegisterReceiptID IS NULL       
AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)
And (p.PlayerID = @PlayerID or @PlayerID = 0)                   
GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID



-->>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
--SKIP CREDIT NOT NEEDED IN THIS REPORT
--THERE"S 2 Script for Discount in RegisterClosing Report 
--DISCOOUNT1 SCRIPT NO DATA OUTPUT SKIP
-->>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

--DISCOUNT 2
insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,Discounts)  
select rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when   1 then   SUM(rd.Quantity * rd.DiscountAmount)  
when  3 then   SUM(rd.Quantity * rd.DiscountAmount)   * -1
end   
FROM RegisterReceipt rr      
left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )      
left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )      
LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )      
left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )      
join Staff s on rr.StaffID = s.StaffID     
left Join Player p on p.PlayerID = rr.PlayerID 
WHERE rd.DiscountTypeID IS NOT NULL       
AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID = 1    
and rr.OperatorID = @OperatorID      
and rd.VoidedRegisterReceiptID IS NULL  
And (p.PlayerID = @PlayerID or @PlayerID = 0)   
GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID               


--COUPON
insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,Coupon)  

 select 

 rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when 1 then sum(rd.Quantity * rd.PackagePrice)
        when 3 then sum(rd.Quantity * rd.PackagePrice) * -1
end   
FROM RegisterReceipt rr      
left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )      
left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )      
LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )      
left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )      
join Staff s on rr.StaffID = s.StaffID   
join CompAward ca on ca.CompAwardID = rd.CompAwardID --filter w coupon
left join Comps c on c.CompID = ca.CompID  
left Join Player p on p.PlayerID = rr.PlayerID 
WHERE  
 rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID in (1,3)      
and rr.OperatorID = @OperatorID      
and rd.VoidedRegisterReceiptID IS NULL  
And (p.PlayerID = @PlayerID or @PlayerID = 0)   

GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID    



--OTHER 

insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,BingoOther)  
select rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when   1 then     SUM(rd.Quantity * rdi.Qty * rdi.Price)
when  3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end
FROM RegisterReceipt rr      
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)      
LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)      
join Staff s on rr.StaffID = s.StaffID   
left Join Player p on p.PlayerID = rr.PlayerID       
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID in (1,3)    
and rr.OperatorID = @OperatorID      
AND (rdi.ProductTypeID IN (8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))      
and rd.VoidedRegisterReceiptID IS NULL   
And (p.PlayerID = @PlayerID or @PlayerID = 0)   
GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID 



-- PULLTAB2
insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,PullTab  )  
SELECT	
rr.GamingDate, sp.GamingSession,RR.TransactionNumber  
,case rr.TransactionTypeID
when 1 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)
when 3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end
FROM RegisterReceipt rr
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
left Join Player p on p.PlayerID = rr.PlayerID
Where 
(rr.GamingDate between @StartDate and @EndDate)
and rr.SaleSuccess = 1
and rr.TransactionTypeID in (1,3)
and rr.OperatorID = @OperatorID
AND rdi.ProductTypeID IN (17)

and rd.VoidedRegisterReceiptID IS NULL	
AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
and (rdi.SalesSourceID = 2)                             -- Register source sales only
And (p.PlayerID = @PlayerID or @PlayerID = 0)      
GROUP BY 	rr.GamingDate, sp.GamingSession,RR.TransactionNumber , rr.TransactionTypeID 



--TAXES
--WHy Session is null then -1

insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,Taxes )  
select rr.GamingDate, 
ISNULL(convert(int, sp.GamingSession), -1), rr.TransactionNumber,
SUM(rd.SalesTaxAmt * rd.Quantity)    
FROM RegisterReceipt rr      
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)      
JOIN Staff s ON (s.StaffID = rr.StaffID)      
left Join Player p on p.PlayerID = rr.PlayerID
Where       
(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID IN (1, 3)      
and rd.VoidedRegisterReceiptID IS NULL       
and (@OperatorID = 0 or rr.OperatorID = @OperatorID )   
And (p.PlayerID = @PlayerID or @PlayerID = 0)          
GROUP BY     rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID      
      
     
      --DEVICE FEES 
      
insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,DeviceFees )  
select rr.GamingDate,  (SELECT TOP 1 ISNULL(sp2.GamingSession, 0) FROM RegisterReceipt rr2      
JOIN RegisterDetail rd2 ON (rr2.RegisterReceiptID = rd2.RegisterReceiptID)      
LEFT JOIN SessionPlayed sp2 ON (sp2.SessionPlayedID = rd2.SessionPlayedID)      
WHERE rr2.RegisterReceiptID = rr.RegisterReceiptID      
ORDER BY sp2.GamingSession)
, rr.TransactionNumber,
isnull(rr.DeviceFee, 0) 
FROM RegisterReceipt rr      
JOIN Staff s ON (s.StaffID = rr.StaffID)    
left Join Player p on p.PlayerID = rr.PlayerID  
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
and rr.SaleSuccess = 1      
and rr.TransactionTypeID = 1      
and rr.OperatorID = @OperatorID      
AND rr.DeviceFee IS NOT NULL      
AND rr.DeviceFee <> 0       
AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)         
  And (p.PlayerID = @PlayerID or @PlayerID = 0)       
    
  
   -->>>>>><<<<<<<<<<
   --SKIP PAYOUT 
   --SKIP PRIZE FEES
   -->>>>>>>>>>>>>>>   
      
      
--PAPER REGISTER SALES    
insert into @SalesActivity 
(GamingDate,GamingSession,ReceiptNumber,Paper )  --Paper only sold from register 
SELECT	
rr.GamingDate, sp.GamingSession,RR.TransactionNumber  
--, SUM(rd.Quantity * rdi.Qty * rdi.Price)    
,case rr.TransactionTypeID
when   1 then     SUM(rd.Quantity * rdi.Qty * rdi.Price)
when  3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end
FROM RegisterReceipt rr
JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where 
(rr.GamingDate between @StartDate and @EndDate)
and rr.SaleSuccess = 1
and rr.TransactionTypeID in (1,3)
and rr.OperatorID = @OperatorID
AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
and rd.VoidedRegisterReceiptID IS NULL	
AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
and (rdi.SalesSourceID = 2 or (SalesSourceID = 1 and rdi.ProductTypeID = 16)) 
--and (rdi.SalesSourceID = 2)                             -- Register source sales only
GROUP BY 	rr.GamingDate, sp.GamingSession,RR.TransactionNumber , rr.TransactionTypeID 


 
    
--(SalesSourceID = 1 and rdi.ProductTypeID = 16)) = CBB (knc 2182013)

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-->>DO NOT KNOW IF THIS ONE COUNT AS A INVENTORY PAPER SALES (floor Sales)
---->>need more investigation
--->> Inventory Sales will never have a transaction number //floor sales
--SELECT	rr.TransactionNumber, 
--			rr.GamingDate, sp.GamingSession, rr.StaffID
--		, rdi.ProductTypeID 
--		, rr.SoldFromMachineID 
--		, isnull(groupName, 'Paper')
--		, rd.PackageName, rdi.ProductItemName
--		, rdi.Price
--		, SUM(rd.Quantity * rdi.Qty)                [Qty]
--		, SUM(rd.Quantity * rdi.Qty * rdi.Price)    [RegisterPaper]
--		, 0                                         [FloorPaper]
--		, 0, 0, 0, 0, 0, 0,0
--	FROM RegisterReceipt rr
--		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--	Where 
--		(rr.GamingDate between @StartDate and @EndDate)
--		and rr.SaleSuccess = 1
--		and rr.TransactionTypeID = 1
--		and rr.OperatorID = @OperatorID
--		AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
--		--And (@Session = 0 or sp.GamingSession = @Session)
--		and rd.VoidedRegisterReceiptID IS NULL	
--		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
--		and (rdi.SalesSourceID = 1)   --**** 1 is INVENTORY *******--
--			GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price, rr.TransactionNumber;
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-->>THIS CODE IS WHAT HAVE TO KEEP TRACK ON FLOORSALES PAPER BUT no Transaction Number
--select 
--			ivtGamingDate
--		, ivtGamingSession
--		, ilStaffID
--		, pi.ProductTypeID
--		, pg.GroupName
--		, 'Floor Sales' [PackageName]  -- req'd b/c no direct link between inventory transaction and packages
--		, pi.ItemName
--		, ivtPrice
--		, CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END     [ReturnsCount]
--		, CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END    [SkipCount]
--		, CASE ivtTransactionTypeID WHEN 24 THEN ivdDelta ELSE 0 END    [BonanzaCount]
--		, CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END    [IssuedCount]
--		, CASE ivtTransactionTypeID WHEN 26 THEN ivdDelta ELSE 0 END    [PlayBackCount]
--		, CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END    [DamagedCount]
--    	, CASE ivtTransactionTypeID WHEN 32 THEN ivdDelta ELSE 0 END    [TransferCount]
--	from InventoryItem 
--	join InvTransaction on iiInventoryItemID = ivtInventoryItemID
--	join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID
--	join InvLocations on ivdInvLocationID = ilInvLocationID
--	left join IssueNames on ivtIssueNameID = inIssueNameID
--	left join ProductItem pi on pi.ProductItemID = iiProductItemID
--	left join ProductGroup pg on pi.ProductGroupID = pg.ProductGroupID
--	where 
--	(pi.OperatorID = @OperatorID)
--	and (ivtGamingDate between @StartDate and @EndDate)
--	and (ivtGamingSession = @Session or @Session = 0)
--	and (ilMachineID <> 0 or ilStaffID <> 0)
--	and pi.ProductTypeID in (1,2,3,4, 16)
--	and pi.SalesSourceID = 1    -- Inventory source sale

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-->> PullTab will be a problem but this one is good for now till 
-->> we hear back from the customer.
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

     

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-->>TEST CODE IF IT MATCH THE REGISTER CLOSING REPORT
----select GamingDate, GamingSession, 
----sum(ConsNMdse) ConsNMdse, 
----sum(Electronics) Electronics,
----sum(Discounts) Discounts,
----sum(BingoOther) Other,
----sum(Taxes) Taxes,
----sum(DeviceFees) DeviceFees,
----sum(Paper) Paper,
----sum(PullTab) PullTab 
----from #a 
----group by GamingDate, GamingSession
----order by GamingDate, GamingSession
-->>>>>>>>>>>>>>>>>>>>>>>>

select * into #a from @SalesActivity --> Transfer all result from @SalesActivity to #a 


select a.GamingDate, a.GamingSession, a.ReceiptNumber,rr.PlayerID ,
sum(Paper) + sum(a.Electronics) + 
sum(a.BingoOther)/*+ SUM(a.Coupon)*/ as BingoSales,
sum(a.PullTab) PullTab ,
sum(a.ConsNMdse)+ sum(a.DeviceFees) + sum(a.Discounts) + SUM(a.Coupon) as  NonGamingSales, 
sum(a.Taxes) Taxes, 

sum(a.ConsNMdse) +
sum(a.Electronics)+ 
sum(a.Discounts) +
SUM(a.Coupon)+ 
sum(a.BingoOther)+
sum(a.Taxes) +
sum(a.DeviceFees)+ 
sum(a.Paper) +
sum(a.PullTab) [Receipt Total] into #Result --> Transfer all result from #a into #result 
from #a a join RegisterReceipt rr on rr.TransactionNumber = a.ReceiptNumber 
--join Player p on rr.PlayerID = a.PlayerID //for some reason cant join it
where rr.PlayerID is not null
--and (rr.PlayerID = @PlayerID /*or @PlayerID = 0*/) 
and (rr.PlayerID = @PlayerID /*or @PlayerID = 0*/) 
group by a.GamingDate, a.GamingSession, a.ReceiptNumber,rr.PlayerID
order by a.GamingDate, a.GamingSession, a.ReceiptNumber,rr.PlayerID



drop table #a 

-->>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<
--This code is for win 
Select	pt.GamingDate,
		pt.PayoutTransNumber,
		p.FirstName,
		p.MiddleInitial,
		p.LastName,
		Sum(isnull(ptdc.Amount, 0) + isnull(ptdch.CheckAmount, 0) + isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)) as Win
,coalesce(sp.GamingSession
,sp2.GamingSession
,sp3.GamingSession
,sp4.GamingSession
,sp5.Gamingsession
,sp6.GamingSession,null)[Session]
into #win
From PayoutTrans pt
Join Player p on pt.PlayerID = p.PlayerID
Join PayoutTransDetailCash ptdc on pt.PayoutTransID = ptdc.PayoutTransID
Left Join PayoutTransDetailCheck ptdch on pt.PayoutTransID = ptdch.PayoutTransID
Left Join PayoutTransDetailMerchandise ptdm on pt.PayoutTransID = ptdm.PayoutTransID
Left Join PayoutTransDetailOther ptdo on pt.PayoutTransID = ptdo.PayoutTransID
left join  PayoutTransBingoGame ptbg on ptbg.PayoutTransID = pt.PayoutTransID
left join sessionGamesPlayed sgp on sgp.SessionGamesPlayedID = ptbg.SessionGamesPlayedID
left join sessionPlayed sp on sp.SessionPlayedID = sgp.sessionPlayedID
left join sessionPlayed sp2 on sp2.sessionPlayedID = ptbg.SessionPlayedID
left join PayoutTransBingoGoodNeighbor ptgn on ptgn.PayoutTransID = pt.PayoutTransID
left join sessiongamesplayed sgp2 on sgp2.SessionGamesPlayedID = ptgn.SessionGamesPlayedID
left join sessionPlayed sp3 on sp3.sessionPlayedID = sgp2.SessionPlayedID
left join PayoutTransBingoCustom ptbc on ptbc.PayoutTransID = pt.PayoutTransID
left join SessionPlayed sp4 on sp4.sessionplayedID = ptbc.sessionplayedid
left join sessiongamesplayed  sgp3 on sgp3.sessiongamesplayedID = ptbc.sessiongamesplayedID
left join sessionplayed sp5 on sp5.sessionplayedID = sgp3.sessionplayedID
left join payoutTransBingoRoyalty ptbr on ptbr.PayoutTransID = pt.PayoutTransID
left join sessiongamesplayed  sgp4 on sgp4.sessiongamesplayedID = ptbr.sessiongamesplayedID
left join sessionplayed sp6 on sp6.sessionplayedID = sgp4.sessionplayedID
Where pt.OperatorID = @OperatorID
And pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)

And (p.PlayerID = @PlayerID /*or @PlayerID = 0*/)
And pt.VoidTransID Is null
Group By pt.GamingDate, pt.PayoutTransNumber, p.LastName, p.FirstName, p.MiddleInitial,sp.GamingSession
,sp2.GamingSession,sp3.GamingSession,sp4.GamingSession ,sp5.Gamingsession,sp6.GamingSession


-->>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<



select r.*, p.FirstName ,p.MiddleInitial,p.LastName, isnull(w.Win,0.00) Win    from #Result r
join Player p on p.PlayerID = r.PlayerID 
left join #win w on w.PayoutTransNumber = r.ReceiptNumber 

--63


drop table #Result 
drop table #win 
     






GO


