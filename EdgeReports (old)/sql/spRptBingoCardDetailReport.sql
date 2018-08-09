USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoCardDetailReport]    Script Date: 07/13/2012 13:47:39 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBingoCardDetailReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBingoCardDetailReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoCardDetailReport]    Script Date: 07/13/2012 13:47:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptBingoCardDetailReport] 

	@StartDate as Datetime,
	@EndDate as Datetime,
	@Session as int,
	@OperatorID as int	
AS
--=============================================================================
-- DE9184 fixed issue with paper cbb cards being returned.
-- 2012.02.14 JKN DE9793 Added support for returning the bonus line numbers
-- 2012.06.12 jkn DE10483 added support for returning the unit serial number
-- 2012.06.28 jkn DE10483 using functions to retrieve unit serial numbers.
-- 2012.07.11 jkn DE10577 Added support for returning voided cards
--=============================================================================

/******************************************************************************
                IMPORTANT NOTE:
                
                If any changes are made to this sp
                then the same changes will need to
                be made to spRptBingoCardDetailSummaryData
                
                
******************************************************************************/

SET NOCOUNT ON;

create table #tSGP (
	GameSeqNo int,
	SessionGamesPlayed int,
	SessionPlayedID int,
	GameName nvarchar(128),
	DisplayGameNo int,
	DisplaypartNo nvarchar(100),
	IsContinued bit
)

insert #tSGP (
	GameSeqNo,
	SessionGamesPlayed,
	SessionPlayedID,
	GameName,
	DisplayGameNo,
	DisplaypartNo,
	IsContinued)
select distinct
	s.GameSeqNo,
	Max(s.SessionGamesPlayedID), 
	s.SessionPlayedID,
	s.GameName,
	s.DisplayGameNo,
	s.DisplaypartNo,
	s.IsContinued
from History.dbo.SessionGamesPlayed s (nolock)
join History.dbo.SessionPlayed sp (nolock) on s.SessionPlayedID = sp.SessionPlayedID
where sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and s.IsContinued = 0	
and sp.isoverridden = 0
Group by s.displaygameno, s.GameSeqno, s.sessionPlayedid, s.gamename,  s.displaypartno, s.iscontinued

create CLUSTERED index I_tSGP_index on #tSGP (SessionGamesPlayed)

declare @TempCardSales table
    (
	RegisterReceiptID  int, 
	TransactionNumber  int, 
	PackNumber  int, 
	DTStamp  datetime, 
	UnitNumber  int, 
	UnitSerialNumber  nvarchar(128),
	GamingDate  smalldatetime, 
	OperatorID  int, 
	SessionPlayedID  int, 
	GamingSession  tinyint,  
	GameSeqNo  int, 
	DisplayPartNo  nvarchar(50),
	DisplayGameNo  int,
	ProgramName  nvarchar(64), 
	RegisterDetailItemID  int, 
	CardCount  smallint, 
	Qty  tinyint, 
	ProductItemName  nvarchar(64), 
	CardMediaID  int,
	CardLvlID  int, 
	CardTypeID  int, 
	GameTypeID  int, 
	CardLvlName  nvarchar(32), 
	CardLvlMultiplier  money,
	PlayerFirstName  nvarchar(32), 
	PlayerLastName  nvarchar(32), 
	StaffFirstName  nvarchar(32), 
	StaffLastName  nvarchar(32), 
	DeviceType  nvarchar(32),
	Quantity  smallint, 
	PackagePrice  money, 
	Price  money, 
	ukslSessionName varchar(15), 
	ukslGamingSession  int, 
	ukslDayofWeek  varchar(15),
	CardNo  int, 
	CardFace  varchar(200), 
	SessionGamesPlayedId  int, 
	MasterCardNo  int,
	CardVoided  bit, 
	IsElectronic  bit, 
	IsQuickPick  bit,
	BonusLineMasterNo  int,
    BonusLineNo nvarchar(32),
	bcdMasterCardNo int,
	bcbdCardTypeID int,
	bcbdMaterCardNo  int,
	bcbdSessionGamesPlayedID  int,	
	CardType nvarchar(32),
	IsCardPlayed bit
	)

insert into @TempCardSales
	(
	RegisterReceiptID, TransactionNumber, PackNumber, DTStamp, UnitNumber, 
	UnitSerialNumber,GamingDate, OperatorID, 
	SessionPlayedID, GamingSession,  DisplayGameNo,
	ProgramName, SessionGamesPlayedID, RegisterDetailItemID, CardCount, Qty, ProductItemName, CardMediaID, CardLvlID,
	CardTypeID, CardType, GameTypeID, CardLvlName, CardLvlMultiplier, PlayerFirstName, PlayerLastName, 
	StaffFirstName, StaffLastName, DeviceType, Quantity, PackagePrice, Price, CardNo, CardFace,  MasterCardNo,bcdMasterCardNo,
	CardVoided, IsElectronic, IsQuickPick, BonusLineMasterNo,
	IsCardPlayed
	)	                                        
 SELECT 
	RR.RegisterReceiptID, RR.TransactionNumber, RR.PackNumber, RR.DTStamp
    -- Begin DE10483 Unit number calculation
    ,dbo.GetLastUnitNumberByTransaction(rr.TransactionNumber)
	,dbo.GetLastUnitSerialNumberByTransaction(rr.TransactionNumber)
	,RR.GamingDate, RR.OperatorID, 
	SP.SessionPlayedID, SP.GamingSession,  DisplayGameNo,
	SP.ProgramName, bchSessiongamesPlayedID,
	RDI.RegisterDetailItemID,  RDI.CardCount, RDI.Qty, RDI.ProductItemName, RDI.CardMediaID,
	RDI.CardLvlID, RDI.CardTypeID, CT.CardType, RDI.GameTypeID, RDI.CardLvlName, RDI.CardLvlMultiplier,
	P.FirstName, P.LastName,S.FirstName, S.LastName, DeviceType,
	Quantity, PackagePrice, Price, 
	bcdCardNo, bcdCardFace, bchMasterCardNo, bcdMasterCardNo,
	bchCardVoided, bchIsElectronic, bchIsQuickPick, bchBonusLineMasterNo,
	case when exists (select top 1 * from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptId) then 1
	     else 0 end
  FROM  RegisterReceipt RR (nolock)
		JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID 
		Join RegisterDetailItems RDI (nolock) on RD.RegisterDetailID = RDI.RegisterDetailID
		left join UnlockLog on (rr.RegisterReceiptId = ulRegisterReceiptId and rr.GamingDate = ulGamingDate)
		Left JOIN Device D (nolock) ON RR.DeviceID = D.DeviceID 
		Left JOIN Player P (nolock)  ON RR.PlayerID = P.PlayerID 
		Left JOIN Staff S (nolock)  ON RR.StaffID = S.StaffID 
		Join BingoCardHeader (nolock) on RDI.registerdetailitemid = bchregisterdetailitemid
		Join BingoCardDetail (nolock) on bcdSessionGamesPlayedID = bchSessionGamesPlayedID
				and bcdMasterCardNo = bchMasterCardNo
		Join (select distinct SessionPlayedID, GamingSession, GamingDate, ProgramName, IsOverridden	--Use derived table to
			from History.dbo.SessionPlayed (nolock)	Where IsOverridden = 0	--eliminate UK duplicates
			) as SP on RD.SessionPlayedID = SP.SessionPlayedID
		Join #tSGP SGP on bchSessionGamesPlayedID = SGP.SessionGamesPlayed
		join ProductType PT (nolock) on RDI.ProductTypeId = PT.ProductTypeID
		JOIN Cardtype CT (nolock) on RDI.CardTypeID = CT.CardTypeID
		left join Machine m (nolock) on ulSoldToMachineID = m.MachineID  
Where RR.GamingDate >= Cast(Convert(varchar(24),@StartDate,101) as smalldatetime)
	And RR.GamingDate <= Cast(Convert(varchar(24),@EndDate,101) as smalldatetime)
	And (@Session = 0 or SP.GamingSession = @Session)
	AND RR.OperatorID = @OperatorID
	and RDI.CardTypeID in (1, 2, 4, 5)
	and RR.SaleSuccess = 1
	and RDI.CardMediaID <> 2 -- Do not include paper cards
	and isnull(voidedregisterreceiptid,0) = 0

----Star Cards
insert into @TempCardSales
	(
	RegisterReceiptID, TransactionNumber, PackNumber, DTStamp, UnitNumber, 
	UnitSerialNumber,GamingDate, OperatorID, 
	SessionPlayedID, GamingSession,  DisplayGameNo,
	ProgramName, SessionGamesPlayedID, 
	RegisterDetailItemID, CardCount, Qty, ProductItemName, CardMediaID, 
	CardLvlID,CardTypeID, CardType, GameTypeID, CardLvlName, CardLvlMultiplier, 
	PlayerFirstName, PlayerLastName, StaffFirstName, StaffLastName, DeviceType, 
	Quantity, PackagePrice, Price, CardNo, CardFace,  MasterCardNo,bcdMasterCardNo,
	CardVoided, IsElectronic, IsQuickPick, BonusLineMasterNo, BonusLineNo,
	IsCardPlayed
	)	                                        
 SELECT
	RR.RegisterReceiptID, RR.TransactionNumber, RR.PackNumber, RR.DTStamp
	, dbo.GetLastUnitNumberByTransaction(rr.TransactionNumber)
	, dbo.GetLastUnitSerialNumberByTransaction(rr.TransactionNumber)
	,RR.GamingDate, RR.OperatorID, 
	SP.SessionPlayedID, SP.GamingSession,  DisplayGameNo,
	SP.ProgramName, bchSessiongamesPlayedID,
	RDI.RegisterDetailItemID,  RDI.CardCount, RDI.Qty, RDI.ProductItemName, RDI.CardMediaID,
	RDI.CardLvlID, RDI.CardTypeID, CT.CardType, RDI.GameTypeID, RDI.CardLvlName, RDI.CardLvlMultiplier,
	P.FirstName, P.LastName,S.FirstName, S.LastName, DeviceType,
	Quantity, PackagePrice, Price, bcdCardNo, bcdCardFace, bchMasterCardNo, bcdMasterCardNo,
	bchCardVoided, bchIsElectronic, bchIsQuickPick, bchBonusLineMasterNo, bcbdBonusLineNo,
	case when exists (select top 1 * from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptId) then 1
	     else 0 end
From RegisterReceipt RR (nolock)
		JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID 
		Join RegisterDetailItems RDI (nolock) on RD.RegisterDetailID = RDI.RegisterDetailID
		Left JOIN Device D (nolock) ON RR.DeviceID = D.DeviceID 
		Left JOIN Player P (nolock)  ON RR.PlayerID = P.PlayerID 
		Left JOIN Staff S (nolock)  ON RR.StaffID = S.StaffID 
		Join BingoCardHeader (nolock) on RDI.registerdetailitemid = bchregisterdetailitemid
		Join BingoCardDetail (nolock) on bcdSessionGamesPlayedID = bchSessionGamesPlayedID
				and bcdMasterCardNo = bchMasterCardNo
		Join BingoCardBonusDefs (nolock) on bcdSessionGamesPlayedID = bcbdSessionGamesPlayedID
				and bcdMasterCardNo = bcbdMasterCardNo
		Join (select distinct SessionPlayedID, GamingSession, GamingDate, ProgramName	--Use derived table to
			from History.dbo.SessionPlayed (nolock)	Where IsOverridden = 0	--eliminate UK duplicates
			) as SP on RD.SessionPlayedID = SP.SessionPlayedID
		Join #tSGP SGP on bchSessionGamesPlayedID = SGP.SessionGamesPlayed
		join ProductType PT (nolock) on RDI.ProductTypeId = PT.ProductTypeID
		JOIN Cardtype CT (nolock) on RDI.CardTypeID = CT.CardTypeID
	Where RR.GamingDate >= Cast(Convert(varchar(24),@StartDate,101) as smalldatetime)
	And RR.GamingDate <= Cast(Convert(varchar(24),@EndDate,101) as smalldatetime)
	And (@Session = 0 or SP.GamingSession = @Session)
	AND RR.OperatorID = @OperatorID
	And RDI.CardtypeID = 3
	and RR.SaleSuccess = 1
	and isnull(voidedregisterreceiptid,0) = 0

declare @BLMasterNo int, @sgpId int, @nums nvarchar(max)
declare bl_cursor cursor for
select distinct BonusLineMasterNo, SessionGamesPlayedID from @TempCardSales where CardTypeId = 2
open bl_cursor
fetch next from bl_cursor into @BLMasterNo, @sgpId
while @@fetch_status = 0
begin
    set @nums = ''

    select @nums = @nums + ltrim(rtrim(str(bcbdBonusLineNo))) + ' ' from BingoCardBonusDefs
        where bcbdMasterCardNo = @BLMasterNo and bcbdSessionGamesPlayedId = @sgpId

    update @TempCardSales set BonusLineNo = @nums
    where BonusLineMasterNo = @BLMasterNo and SessionGamesPlayedID = @sgpId

    fetch next from bl_cursor into @BLMasterNo, @sgpId
end

close bl_cursor
deallocate bl_cursor

Select distinct * from @TempCardSales

Drop table #tSGP

GO

