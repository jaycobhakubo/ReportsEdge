USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubtElectronicSales]    Script Date: 07/14/2015 15:03:10 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubtElectronicSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubtElectronicSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubtElectronicSales]    Script Date: 07/14/2015 15:03:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--exec sp_helptext 'spRptElectronicSales'





CREATE procedure [dbo].[spRptSubtElectronicSales]
-- ============================================================================
-- Author:		Karlo Camacho 
-- Date:		12/3/2012 
-- Comment:		Copied from Store Procedure spRpElectronicSales
-- 20150714 (tmp) DE12613 - Corrected the card count when a game is replayed.
-- ===========================================================================

@OperatorID int,
@StartDate datetime,
@Session int
as
begin

declare @EndDate datetime
set @EndDate = @StartDate


declare @ElectronicSales table
(
 RegisterReceiptID int
,OriginalRegisterReceiptID int
,VoidedRegisterReceiptID int
,StaffID int
,GamingSession int
,TransactionNumber int
,DTStamp datetime
,SerialNumber nvarchar(64)
,PackNumber int
,NoOfCards int
,Price money
)

declare @CardCount table

(
totalCards int,
registerRecieptId int
);  

 declare @AllCardNumbers table
(        
cardNo int,
sessionGamesPlayedID int,
registerReceiptID int
)

insert into @AllCardNumbers

select  bcd.bcdCardNo,bcd.bcdSessionGamesPlayedID, rr.RegisterReceiptID from RegisterReceipt rr
join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
join BingoCardHeader bch on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID
join BingoCardDetail bcd on bch.bchMasterCardNo = bcd.bcdMasterCardNo 
	and bch.bchSessionGamesPlayedID = bcd.bcdSessionGamesPlayedID
join SessionGamesPlayed sgp on bcd.bcdSessionGamesPlayedId = sgp.SessionGamesPlayedId
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
and rr.GamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime) 
and rr.OperatorID = @OperatorID
and (rdi.CardMediaId = 1 or rdi.CardMediaId is null)
and sgp.IsContinued = 0

insert @CardCount
select COUNT(Distinct(cardno)) /* DE12613 */, RegisterReceiptID 

	from @AllCardNumbers t
	group by t.registerReceiptID;

insert into @ElectronicSales
(
 RegisterReceiptID
,OriginalRegisterReceiptID
,VoidedRegisterReceiptID
,StaffID
,GamingSession
,TransactionNumber
,DTStamp
,SerialNumber
,PackNumber
,NoOfCards
,Price
)       

select rr.RegisterReceiptID
	,rr.OriginalReceiptID
	,rd.VoidedRegisterReceiptID
	,rr.StaffID
	,sp.GamingSession
	,rr.TransactionNumber
	,rr.DTStamp
	,case when ulSoldToMachineId is null then ulUnitSerialNumber else(case when m.SerialNumber is null then m.ClientIdentifier else m.SerialNumber end) end
	,rr.PackNumber
	,0.0 as CardCount --DE10084
	,sum(rdi.Price * rdi.Qty * rd.Quantity) as Price
from RegisterReceipt rr
join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId
left join UnlockLog ul on (ulID = (select top 1 ulID
			from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptID
				and ulPackLoginAssignDate is not null
			order by ulPackLoginAssignDate desc))
left join Machine m on m.MachineID = ulSoldToMachineID
where RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and RR.SaleSuccess = 1
and RDI.CardMediaID = 1
and RR.OperatorID = @OperatorID
and (@Session = 0 or sp.GamingSession = @Session)
group by 
	 rr.RegisterReceiptID
	,rr.OriginalReceiptID
	,sp.GamingSession
	,RR.TransactionNumber
,RR.DTStamp
	,RR.PackNumber
	,m.SerialNumber
	,m.ClientIdentifier
	,ulSoldToMachineId
	,RR.StaffID
	,RD.VoidedRegisterReceiptID
	,ulRegisterReceiptID
	,ulUnitSerialNumber
---Voids

insert into @ElectronicSales
(
	 RegisterReceiptID
	,OriginalRegisterReceiptID
	,VoidedRegisterReceiptID
	,StaffID
	,GamingSession
	,TransactionNumber
	,DTStamp
	,SerialNumber
	,PackNumber
	,NoOfCards
	,Price
)       

select  rr.RegisterReceiptID
	,rr.OriginalReceiptID
	,rd.VoidedRegisterReceiptID
	,rr.StaffID
	,es.GamingSession
	,rr.TransactionNumber
	,rr.DTStamp
	,rr.UnitSerialNumber
	,es.PackNumber
	,es.NoOfCards
	,es.Price
from   RegisterReceipt rr
       left join RegisterDetail rd ON rr.RegisterReceiptID = rd.RegisterReceiptID
       left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	   join @ElectronicSales es on rr.OriginalReceiptID = es.RegisterReceiptID
where   rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	    and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
    	and(rdi.CardMediaID = 1 or rdi.CardMediaID is null)
	    and rr.TransactionTypeID = 2
	    and rr.OperatorID = @OperatorID
	    --why theres no session filter ??kc 12/11/2012 
	   -- and (@Session = 0 or es.GamingSession = @Session)--added 12/11/2012
	    
update @ElectronicSales
set NoOfCards = Card_Count from (select totalCards as Card_Count, registerRecieptId as r_r from @CardCount) as [A]
                where RegisterReceiptID = r_r
                and OriginalRegisterReceiptID is null
declare @rrID int;
declare @orrID int;
declare void_cursor cursor for
select RegisterReceiptID, OriginalRegisterReceiptID  
        from @ElectronicSales
        where OriginalRegisterReceiptID is not null;
open  void_cursor;
fetch next from void_cursor into @rrID, @orrID;                 
while @@FETCH_STATUS = 0
begin
update @ElectronicSales
	set NoOfCards = (select totalcards from @CardCount where registerRecieptId= @orrID)
	where RegisterReceiptID = @rrID; 
	fetch next from void_cursor into @rrID, @orrID;
end
close void_cursor;
deallocate void_cursor;



select a.RegisterReceiptID
	,a.OriginalRegisterReceiptID
	,a.VoidedRegisterReceiptID
	,a.StaffID
	,a.GamingSession
	,a.TransactionNumber
	,a.DTStamp,
	case 
	when a.OriginalRegisterReceiptID IS null then a.SerialNumber
	when a.OriginalRegisterReceiptID IS not null  then b.SerialNumber 
	end as	[SerialNumber]
	,a.PackNumber
	,a.NoOfCards
	,a.Price
from @ElectronicSales a left join @ElectronicSales b 
on a.OriginalRegisterReceiptID = b.RegisterReceiptID
order by a.TransactionNumber

end



















GO

