USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptVIPReport]    Script Date: 04/03/2014 12:57:08 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptVIPReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptVIPReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptVIPReport]    Script Date: 04/03/2014 12:57:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-------------------------------------------------------------------------------
-- 2013.09.20 tmp: DE11233 - Add device fees to voided transactions
-- 2014.04.03 tmp: DE11698 - Returns player's sales for all operators. 
-------------------------------------------------------------------------------


CREATE PROCEDURE [dbo].[spRptVIPReport]
	@StartDate		AS	SmallDateTime,
	@EndDate		AS	SmallDateTime,
	@OperatorID		AS	Int,
	@PlayerID		AS	Int
		
AS

SET NOCOUNT ON
	--set @EndDate = Dateadd(Day,1,@EndDate)

create table #tempVIP (
	PlayerID int,
	FirstName varchar(50),
	LastName varchar(50), 
	GameTransID bigint,
	TransactionType nvarchar(64),
	GameName nvarchar(100),
	TransTotal money,
	TransactionTypeID int,
	gtTransactionTypeID int,
	TransDate datetime,
	Delta money,
	Previous money,
	Post money,
	VoidDate datetime,
	VoidStaffID int,
	GamingDate datetime,
	UnitNumber int,
	PackNumber int,
	Tax money,
	DeviceFee money,
	AmountTendered money,
	PreSalePoints money,
	UnitSerialNumber nvarchar(30),
	StaffID int,
	OperatorID int,
	SaleSuccess bit,
	RegisterReceiptID int,
	OriginalReceiptID int,
	RegisterDetailID int,
	PackageName nvarchar(128),
	PackagePrice money,
	ReceiptLine int,
	Quantity int,
	DiscountAmount money, 
	DiscountPtsPerDollar money,
	TotalPtsEarned money,
	VoidedregisterReceiptID int,
	TotalPtsRedeemed money,
	DeviceType nvarchar(32)
)
--Register sales, cashouts
insert #tempVIP 
		(PlayerID, FirstName, LastName, 
		GamingDate, GameTransID, UnitNumber, PackNumber, TransDate, Tax, DeviceFee, 
		AmountTendered, PreSalePoints, UnitSerialNumber, TransactiontypeID, StaffID, OperatorID,
		SaleSuccess, RegisterReceiptID, OriginalReceiptID, Delta, gtTransactionTypeID,
		RegisterDetailID, PackageName, PackagePrice, ReceiptLine, Quantity, DiscountAmount, 
		DiscountPtsPerDollar, TotalPtsEarned, VoidedregisterReceiptID, TotalPtsRedeemed,
		TransactionType, DeviceType, Previous, Post, VoidDate)
SELECT  P.PlayerID, P.FirstName, P.LastName, 
		RR.GamingDate, RR.TransactionNumber, RR.UnitNumber, RR.PackNumber, RR.DTStamp, RD.SalesTaxAmt, RR.DeviceFee, 
		RR.AmountTendered, RR.PreSalePoints, RR.UnitSerialNumber, RR.TransactiontypeID, RR.StaffID, RR.OperatorID,
		RR.SaleSuccess,	RR.RegisterReceiptID, RR.OriginalReceiptID, gtTransTotal,gtTransactionTypeID,
		RD.RegisterDetailID, 
		case when rd.PackageName IS NULL and ca.CompAwardID IS not null then rd.PackageReceiptText
		else rd.PackageName end,		
		RD.PackagePrice, RD.ReceiptLine, RD.Quantity, RD.DiscountAmount, 
		RD.DiscountPtsPerDollar, RD.TotalPtsEarned, RD.VoidedregisterReceiptID, RD.TotalPtsRedeemed,
		TT.TransactionType, D.DeviceType , gtdPrevious, gtdPost, gtdVoidDate
FROM Player P (nolock)
Join PlayerInformation PIN (nolock) on P.PlayerID = PIN.PlayerID
JOIN RegisterReceipt RR (nolock) ON P.PlayerID = RR.PlayerID
left JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID
Left Join History.dbo.GameTrans (nolock) on RR.RegisterReceiptID = gtregisterReceiptID -- JLW Need all now and gtTransactiontypeID = 12 
left Join History.dbo.GametransDetail (nolock)
	on gtGametransID = GTDGameTransID 
left Join TransactionType TT(nolock) on RR.TransactiontypeID = TT.TransactiontypeID
left Join Device D (nolock) on RR.DeviceId = D.DeviceID
left Join CompAward ca on rd.CompAwardID = ca.CompAwardID
left Join Comps c on ca.CompID = c.CompID
WHERE RR.GamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime)
and RR.GamingDate  <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime)
AND rr.OperatorID = @OperatorID  -- DE11698 Added condition rr.OperatorID 
And PIN.OperatorID = @OperatorID 
and (@PlayerID = 0 or RR.PlayerID = @PlayerID)
and RR.TransactiontypeID in (1,3,12, 10)
and SaleSuccess = 1

--Register Voids
insert #tempVIP 
		(PlayerID, FirstName, LastName, 
		GamingDate, GameTransID, UnitNumber, PackNumber, TransDate, Tax, DeviceFee, 
		AmountTendered, PreSalePoints, UnitSerialNumber, TransactiontypeID, StaffID, OperatorID,
		SaleSuccess, RegisterReceiptID, OriginalReceiptID, Delta, gtTransactionTypeID,
		RegisterDetailID, 
		PackageName, 
		PackagePrice, ReceiptLine, Quantity, DiscountAmount, 
		DiscountPtsPerDollar, TotalPtsEarned, VoidedregisterReceiptID, TotalPtsRedeemed,
		TransactionType, DeviceType, Previous, Post, VoidDate)
SELECT  P.PlayerID, P.FirstName, P.LastName, 
		RR.GamingDate, RR.TransactionNumber, RR.UnitNumber, RR.PackNumber, RR.DTStamp, RD.SalestaxAmt, RR.DeviceFee, 
		RR.AmountTendered, RR.PreSalePoints, RR.UnitSerialNumber, RR.TransactiontypeID, RR.StaffID, RR.OperatorID,
		RR.SaleSuccess,	RR.RegisterReceiptID, RR.OriginalReceiptID, gtTransTotal,gtTransactionTypeID,
		RD.RegisterDetailID, 
		case when rd.PackageName IS NULL and ca.CompAwardID IS not null then rd.PackageReceiptText
		else rd.PackageName end,		
		RD.PackagePrice, RD.ReceiptLine, RD.Quantity, RD.DiscountAmount, 
		RD.DiscountPtsPerDollar, RD.TotalPtsEarned, RD.VoidedregisterReceiptID, RD.TotalPtsRedeemed,
		TT.TransactionType, D.DeviceType , gtdPrevious, gtdPost, gtdVoidDate
FROM Player P (nolock)
Join PlayerInformation PIN (nolock) on P.PlayerID = PIN.PlayerID
JOIN RegisterReceipt RR (nolock) ON P.PlayerID = RR.PlayerID
JOIN RegisterDetail RD (nolock) ON RR.OriginalReceiptID = RD.RegisterReceiptID
Left Join History.dbo.GameTrans (nolock) on RR.OriginalReceiptID = gtregisterReceiptID --JLW need all now and gtTransactionTypeID = 10
left Join History.dbo.GametransDetail (nolock)
	on gtGametransID = GTDGameTransID 
left Join TransactionType TT(nolock) on RR.TransactiontypeID = TT.TransactiontypeID
left Join Device D (nolock) on RR.DeviceId = D.DeviceID
left Join CompAward ca on rd.CompAwardID = ca.CompAwardID
left Join Comps c on ca.CompID = c.CompID
WHERE (RR.GamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime)
and RR.GamingDate  <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime))
AND rr.OperatorID = @OperatorID -- DE11698 Added condition rr.OperatorID 
And PIN.OperatorID = @OperatorID 
and (@PlayerID = 0 or RR.PlayerID = @PlayerID)
and RD.VoidedregisterReceiptID > 0
and RR.TransactiontypeID = 2

-- Update Device Fees on Register Voids
Update #tempVIP
Set #tempVIP.DeviceFee = (Select DeviceFee From RegisterReceipt rr
							Where #tempVIP.OriginalReceiptID = rr.RegisterReceiptID)
Where #tempVIP.TransactionTypeID = 2

--Credit CashOut
--JLW removed and placed above. Not necessary now that all points are in gametrans

--Credit Spend
insert #tempVIP 
		(PlayerID, GameTransID, TransDate, Delta, Previous, Post, TransactionTypeID, OperatorID,
		LastName, FirstName, TransactionType, GameName)
select gtPlayerID, gtGameTransID, gtTransDate, gtdDelta, gtdPrevious,  gtdPost, gtTransactionTypeID, gtOperatorID,
		LastName, FirstName, Transactiontype, ModuleName
From Player P(nolock)
Join PlayerInformation PIN (nolock) on P.PlayerID = PIN.PlayerID
Join History.dbo.GameTrans (nolock) on P.PlayerID = gtPlayerID
Left join History.dbo.GameTransDetail (nolock) on gtGameTransID = gtdGameTransID
Left join GameIPPlayHistory (nolock) on gtGameTransID = ihWinGameTransID
Left Join TransactionType (nolock) on gtTransactionTypeID = TransactiontypeID
Left Join Modules  (nolock) on gtmoduleid = ModuleID
where gtGamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime) -- JLW removed Cast(Convert
and gtGamingDate  <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime)
and (@PlayerID = 0 or gtPlayerID = @PlayerID)
And PIN.OperatorID = @OperatorID 
and gtOperatorID = @OperatorID -- DE11698 Added condition gtOperatorID 
and gtTransactionTypeID = 15

--Credit win
insert #tempVIP 
		(PlayerID, GameTransID, TransDate, Delta, Previous, Post, TransactionTypeID, OperatorID,
		LastName, FirstName, TransactionType, GameName)
select gtPlayerID, gtGameTransID, gtTransDate, gtdDelta, gtdPrevious,  gtdPost, gtTransactionTypeID, gtOperatorID,
		LastName, FirstName, Transactiontype, ModuleName
From  Player P (nolock)
Join PlayerInformation PIN (nolock) on P.PlayerID = PIN.PlayerID
left join History.dbo.GameTrans (nolock) on P.PlayerID = gtPlayerID 
Left join History.dbo.GameTransDetail (nolock) on gtGameTransID = gtdGameTransID
Left join GameIPPlayHistory (nolock) on gtGameTransID = ihBuyGameTransID
Left Join TransactionType (nolock) on gtTransactionTypeID = TransactiontypeID
Left Join Modules  (nolock) on ihgameid = ModuleID
where gtgamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime) --JLW removed Cast(Convert
and  gtgamingDate <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime)
and (@PlayerID = 0 or gtPlayerID = @PlayerID)
And PIN.OperatorID = @OperatorID 
and gtOperatorID = @OperatorID -- DE11698 Added condition gtOperatorID 
and gttransactiontypeid = 13

--4-27-2009 Get Swipe Station Activity

insert #tempVIP 
		(PlayerID, GameTransID, RegisterReceiptID, TransactionType, GamingDate, TransDate, TotalPtsEarned, PreSalepoints, Post, TransactionTypeID, OperatorID,
		LastName, FirstName, Quantity)
select gtPlayerID,  gtGameTransID, gtgameTransID, gtTransactionTypeID, gtGamingDate, gtTransDate, gtTransTotal, gtdPrevious,  gtdPost, gtTransactionTypeID, gtOperatorID,
		LastName, FirstName, '1' --Added Quantity JLW
From  Player P (nolock)
Join PlayerInformation PIN (nolock) on P.PlayerID = PIN.PlayerID
join History.dbo.GameTrans (nolock) on P.PlayerID = gtPlayerID 
join History.dbo.GameTransDetail (nolock) on gtGameTransID = gtdGameTransID
where gtGamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime)
and gtGamingDate  <= CAST(CONVERT(VARCHAR(24), @EndDate, 101) AS SmallDateTime)
and (@PlayerID = 0 or gtPlayerID = @PlayerID)
And PIN.OperatorID = @OperatorID 
and gtOperatorID = @OperatorID -- DE11698 Added condition gtOperatorID 
and isnull(gtRegisterReceiptID, 0) = 0 
and gttransactiontypeid = 9  -- JLW 8-12-2009 Only Swipe Station records

select * from #tempVIP
order by TransDate, Transactiontype

drop table #tempVIP

SET NOCOUNT OFF




















GO

