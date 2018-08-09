﻿
GO

/****** Object:  StoredProcedure [dbo].[CBBCardSalesSummary]    Script Date: 07/03/2012 14:50:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CBBCardSalesSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[CBBCardSalesSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[CBBCardSalesSummary]    Script Date: 07/03/2012 14:50:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE proc [dbo].[CBBCardSalesSummary]

@OperatorID	as Int,
	@Session	as Int,
	@StartDate	As DateTime,
	@EndDate	As DateTime

	
	as
begin
--set @StartDate = '7/03/2012 00:00:00'
--set @EndDate = '7/03/2013 00:00:00'
--set @Session = 0
--set @OperatorID = 1

--exec CBBCardSalesSummary 1,1,'6/27/2012 00:00:00','6/28/2012 00:00:00'

     SELECT SP.SessionPlayedID, FirstName, LastName, P.PlayerID, DeviceType, 
		RR.SaleSuccess, RR.TransactionNumber, RR.TransactionTypeID, RR.GamingDate, RR.StaffID, 
		RR.OperatorID, RR.DTStamp, RR.RegisterReceiptID,
		bcdCardNo, bcdCardFace, bcdSessionGamesPlayedId, bcdMasterCardNo,
		SP.GamingSession, 
		SGP.GameName, SGP.GameSeqNo, SGP.DisplayGameNo, SGP.DisplayPartNo, SGP.SessionGamesPlayedID, 
		ProductItemName, ProductType, 
		bchMasterCardNo, bchBonusLineMasterNo, bchSessionGamesPlayedID, bchCardVoided, bchIsElectronic, 
		bchIsQuickPick, 
		RD.RegisterDetailID, Quantity, PackagePrice, 
		RDI.RegisterDetailItemID, Qty, Price, 
		RR1.TransactionNumber as VTrans, RR1.TransactionTypeID as VType,
		bcbdMasterCardNo, bcbdCardTypeID, bcbdBonusLineNo bcbdSessionGamesPlayedID
		into #a
	FROM   RegisterReceipt RR (nolock)
		Left join RegisterReceipt RR1 (nolock) on (RR.RegisterReceiptID = RR1.OriginalReceiptID and RR.Transactiontypeid <> 14)
		JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID 
		Join RegisterDetailItems RDI (nolock) on RD.RegisterDetailID = RDI.RegisterDetailID
		Left JOIN Device D (nolock) ON RR.DeviceID = D.DeviceID 
		Left JOIN Player P (nolock)  ON RR.PlayerID = P.PlayerID 
		Join BingoCardHeader (nolock) on RDI.registerdetailitemid = bchregisterdetailitemid
		Join BingoCardDetail (nolock) on bcdSessionGamesPlayedID = bchSessionGamesPlayedID
				and bcdMasterCardNo = bchMasterCardNo
		Left Join BingoCardBonusDefs (nolock) on bcdSessionGamesPlayedID = bcbdSessionGamesPlayedID
				and bcdMasterCardNo = bcbdMasterCardNo
		--No longer valid table 4-5-09 JOIN History.dbo.BingoCardSales CCS (nolock)  ON RDI.RegisterDetailItemID = CCS.RegisterDetailItemID 
		--JOIN History.dbo.SessionPlayed (nolock)  SP ON RD.SessionPlayedID = SP.SessionPlayedID
		Join (select distinct SessionPlayedID, GamingSession, GamingDate, ProgramName	--Use derived table to
			from History.dbo.SessionPlayed (nolock)		--eliminate UK duplicates
			) as SP on RD.SessionPlayedID = SP.SessionPlayedID
		--join History.dbo.SessionGamesPlayed SGP (nolock) on (SGP.SessionPlayedID = SP.SessionPlayedID)
		Join(select distinct SessionGamesPlayedID, SessionPlayedID, GameName, GameSeqNo, DisplayGameNo, DisplaypartNo	--Use derived table to
			from History.dbo.SessionGamesPlayed (nolock)		--eliminate UK duplicates
			) as SGP on RD.SessionPlayedID = SGP.SessionPlayedID and bchSessionGamesPlayedID = SGP.SessiongamesPlayedID
		join ProductType PT (nolock) on RDI.ProductTypeId = PT.ProductTypeID
	WHERE  RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
	AND (@Session = 0 or SP.GamingSession = @Session)
	AND RR.OperatorID = @OperatorID
	and RDI.ProductTypeID in ('1','2','3','4')
	and RR.TransactionTypeID <> 14
	AND RR.SaleSuccess = 1
Set NoCount off

select GamingDate [Date], GamingSession [Session], GameName [Game Name],(count(bchIsElectronic))-(isnull(b.NbrCardVoid_P,0)) as NbrCardSold_P,isnull(b.NbrCardVoid_P,0)NbrCardVoid_P ,
(count(bchIsElectronic))-(isnull(b.NbrCardVoid_P,0))*Price Sales_P--sum(Price) Sales_P 
into #b
from #a 
full join (select GamingDate [Date], GamingSession [Session], GameName [Game Name],count(bchIsElectronic)NbrCardVoid_P --,VTrans
from #a 
where bchIsElectronic = 0 and Vtrans is not null
group by GamingDate , GamingSession , GameName )  b  on b.[Date] = GamingDate and b.[Session] = GamingSession and b.[Game Name] =GameName

where bchIsElectronic = 0 
group by GamingDate , GamingSession , GameName ,b.NbrCardVoid_P ,Price


select GamingDate [Date], GamingSession [Session], GameName [Game Name], (count(bchIsElectronic)-isnull(b.NbrCardVoid_E,0))NbrCardSold_E,isnull(b.NbrCardVoid_E,0)NbrCardVoid_E ,
(count(bchIsElectronic))-(isnull(b.NbrCardVoid_E,0))*price Sales_E 
into #c
from #a 
left join (select GamingDate [Date], GamingSession [Session], GameName [Game Name], count(bchIsElectronic)NbrCardVoid_E --,VTrans,VType 

from #a 
where bchIsElectronic = 1 and (VType = 2)
group by GamingDate , GamingSession , GameName) b on b.[Date] = GamingDate and b.[Session] = GamingSession and b.[Game Name] =GameName
where bchIsElectronic = 1
group by GamingDate, GamingSession , GameName , b.NbrCardVoid_E,price 


select 
a.[date],a.[Session],a.[Game Name],a.NbrCardSold_P, a.NbrCardVoid_P ,a.Sales_P,
b.NbrCardSold_E, b.NbrCardVoid_E, b.Sales_E,
isnull(a.NbrCardSold_P,0) + isnull(b.NbrCardSold_E,0) as NbrCardSold_T ,
isnull(a.NbrCardVoid_P,0) + isnull(b.NbrCardVoid_E,0) as NbrCardVoid_T,
isnull(a.Sales_P,0) + isnull(b.Sales_E,0)as Sales_T     
from #b a join #c b on a.[Date] = b.[Date] and a.Session = b.Session and a.[Game Name] = b.[Game Name] 

drop table #a
drop table #b
drop table #c 

end





GO


