USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCBBCardSalesReport]    Script Date: 7/11/2013 2:42:10 PM ******/
DROP PROCEDURE [dbo].[spRptCBBCardSalesReport]
GO

/****** Object:  StoredProcedure [dbo].[spRptCBBCardSalesReport]    Script Date: 7/11/2013 2:42:10 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptCBBCardSalesReport] 
	@StartDate	As DateTime,
	@EndDate	As DateTime,
	@Session	as Int,
	@OperatorID	as Int
AS
set nocount on
BEGIN

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
	FROM   RegisterReceipt RR (nolock)
		Left join RegisterReceipt RR1 (nolock) on (RR.RegisterReceiptID = RR1.OriginalReceiptID and RR.Transactiontypeid <> 14)
		JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID 
		Join RegisterDetailItems RDI (nolock) on RD.RegisterDetailID = RDI.RegisterDetailID
		Left JOIN Device D (nolock) ON RR.DeviceID = D.DeviceID 
		Left JOIN Player P (nolock)  ON RR.PlayerID = P.PlayerID 
		Join BingoCardHeader bch (nolock) on RDI.registerdetailitemid = bchregisterdetailitemid
		Join BingoCardDetail bcd (nolock) on bcdSessionGamesPlayedID = bchSessionGamesPlayedID
				and bcdMasterCardNo = bchMasterCardNo
		Left Join BingoCardBonusDefs (nolock) on bcdSessionGamesPlayedID = bcbdSessionGamesPlayedID
				and bcdMasterCardNo = bcbdMasterCardNo
		--No longer valid table 4-5-09 JOIN History.dbo.BingoCardSales CCS (nolock)  ON RDI.RegisterDetailItemID = CCS.RegisterDetailItemID 
		--JOIN History.dbo.SessionPlayed (nolock)  SP ON RD.SessionPlayedID = SP.SessionPlayedID
		Join (select distinct SessionPlayedID, GamingSession, GamingDate, ProgramName	--Use derived table to
			from SessionPlayed (nolock)		--eliminate UK duplicates --use daily db rather than history
			) as SP on RD.SessionPlayedID = SP.SessionPlayedID
		--join History.dbo.SessionGamesPlayed SGP (nolock) on (SGP.SessionPlayedID = SP.SessionPlayedID)
		--Join(select distinct SessionGamesPlayedID, SessionPlayedID, GameName, GameSeqNo, DisplayGameNo, DisplaypartNo	--Use derived table to
		--	from History.dbo.SessionGamesPlayed (nolock)		--eliminate UK duplicates
		--	) as SGP on RD.SessionPlayedID = SGP.SessionPlayedID and bchSessionGamesPlayedID = SGP.SessiongamesPlayedID
		Join (select Max(SessionGamesPlayedID) as SessionGamesPlayedID, SessionPlayedID, GameName, GameSeqNo, DisplayGameNo, DisplaypartNo	--DE10984 eliminate replayed games
			from SessionGamesPlayed		--use daily db rather than history
			Group By SessionPlayedID, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName
			) As SGP on RD.SessionPlayedID = SGP.SessionPlayedID and bchSessionGamesPlayedID = SGP.SessionGamesPlayedID
		join ProductType PT (nolock) on RDI.ProductTypeId = PT.ProductTypeID
	WHERE  RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
	AND (@Session = 0 or SP.GamingSession = @Session)
	AND RR.OperatorID = @OperatorID
	and RDI.ProductTypeID in ('1','2','3','4')
	and RR.TransactionTypeID <> 14
	AND RR.SaleSuccess = 1
	Group By SP.SessionPlayedID, FirstName, LastName, P.PlayerID, DeviceType, 
		RR.SaleSuccess, RR.TransactionNumber, RR.TransactionTypeID, RR.GamingDate, RR.StaffID, 
		RR.OperatorID, RR.DTStamp, RR.RegisterReceiptID,
		bcd.bcdCardNo, bcd.bcdCardFace, bcd.bcdSessionGamesPlayedId, bcd.bcdMasterCardNo,
		SP.GamingSession, 
		SGP.GameName, SGP.GameSeqNo, SGP.DisplayGameNo, SGP.DisplayPartNo, SGP.SessionGamesPlayedID, 
		ProductItemName, ProductType, 
		bch.bchMasterCardNo, bch.bchBonusLineMasterNo, bch.bchSessionGamesPlayedID, bch.bchCardVoided, bch.bchIsElectronic, bch.bchIsQuickPick, 
		RD.RegisterDetailID, Quantity, PackagePrice, 
		RDI.RegisterDetailItemID, Qty, Price, 
		RR1.TransactionNumber, RR1.TransactionTypeID,
		bcbdMasterCardNo, bcbdCardTypeID, bcbdBonusLineNo, bcbdSessionGamesPlayedID
Set NoCount off
END


GO

