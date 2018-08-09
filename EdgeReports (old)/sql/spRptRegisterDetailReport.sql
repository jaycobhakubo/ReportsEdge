USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterDetailReport]    Script Date: 08/02/2012 08:33:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterDetailReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterDetailReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterDetailReport]    Script Date: 08/02/2012 08:33:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[spRptRegisterDetailReport]
	@StartDate		AS	SmallDateTime,
	@EndDate		AS	SmallDateTime,
	@OperatorID		AS	Int,
	@StaffID		AS	Int,
	@Session		AS	Int		
AS
-- =============================================
-- Execution Test Case - Tygh Porak
/* =============================================
   DECLARE
   @startTime			DATETIME
   
   SET @startTime = GETUTCDATE();
   
   EXECUTE [dbo].[spRptRegisterDetailReport]
		@OperatorID		= 1,
		@StartDate		= '01/01/2011 00:00:00',
		@EndDate		= '06/01/2011 00:00:00',
		@session		= 1
		
   PRINT 'Execution Time : '
		+ CAST(DATEDIFF(ms, @startTime, GETUTCDATE()) AS NVARCHAR(20))
				+ ' milliseconds'
-- ===============================================================================*/
-- 2012.01.18 jkn: DE9944 include the device fees in the voids
-- 2012.06.12 jkn: DE10482 Added support for retrieving the serial number and unit numbers
-- 2012.06.14 jkn: TA11132 Added support for returning the void transaction number
-- 2012.06.26 jkn: DE10532 Added support for returning the transfered to unit number
-- 2012.07.26 jkn: NGCB return the product type for calculation purposes
-- 2012.08.01 jkn: DE10641 Fixed issue with returning device fees for every item 
--  in a transaction now only the first item will have a device fee associated
--  with it.
-- ===============================================================================
	
SET NOCOUNT ON;
--
-- Determine if sales are using exchange rates (Global Setting -> Operator Setting)
--
DECLARE @SettingValue NVARCHAR(200),
		@UseExchangeRate BIT

SELECT	@SettingValue = 'true',
		@UseExchangeRate = 1

SELECT @SettingValue = SettingValue
FROM GlobalSettings 
WHERE GlobalSettingID = 50

IF EXISTS (SELECT * FROM OperatorSettings where OperatorID = @OperatorID AND GlobalSettingID = 50)
BEGIN
	SELECT @SettingValue = SettingValue
	FROM OperatorSettings
	WHERE OperatorID = @OperatorID 
		AND GlobalSettingID = 50
END

IF (LEN(LTRIM(@SettingValue)) > 0)
BEGIN
	SELECT @SettingValue = LEFT(LTRIM(@SettingValue), 1)
	
	IF (@SettingValue = 'T' OR
		@SettingValue = 't' OR
		@SettingValue = '1')
	BEGIN
		SELECT @UseExchangeRate = 1
	END
	ELSE
	BEGIN
		SELECT @UseExchangeRate = 0
	END	
END

create table #TempRegisterSales
		(
		GamingDate SmallDateTime, 
		TransactionNumber int, 
		UnitNumber nvarchar(60), 
		PackNumber int, 
		DTStamp datetime, 
		Tax money, 
		DeviceFee money, 
		AmountTendered money, 
		PreSalePoints money, 
		UnitSerialNumber nvarchar(60), 
		TransactiontypeID int, 
		StaffID int, 
		OperatorID int,
		SaleSuccess bit,	
		RegisterReceiptID int, 
		OriginalReceiptID int, 
		OriginalTransactionNumber int,
		PlayerID int, 
		RegisterDetailID int, 
		PackageName nvarchar(64), 
		PackagePrice money, 
		ReceiptLine int, 
		Quantity int, 
		DiscountAmount money, 
		DiscountPtsPerDollar money, 
		TotalPtsEarned money, 
		VoidedregisterReceiptID int, 
		TotalPtsRedeemed money,
		CardCount int,	
		Price money, 
		Qty int, 
		CardLvlName nvarchar(64), 
		CardLvlID int, 
		RegisterDetailItemID int, 
		ProductItemName nvarchar(64),
		ProductTypeId int,
		FirstName nvarchar(64), 
		LastName nvarchar(64), 
		PFirstName nvarchar(64), 
		PLastName nvarchar(64), 
		DiscountTypeName nvarchar(64), 
		TransactionType nvarchar(64),  
		GamingSession int, 
		VGamingSession int,
		--OriginalTrans int, 
		VoidTransactionNumber int,
		VoidReceipt int,  
		VQuantity int, 
		VDiscountAmount money, 
		VStaffFirstName nvarchar(64), 
		VStaffLastName nvarchar(64),
		VReceiptLine int, 
		VTotalPtsRedeemed money, 
		VDiscountPtsPerDollar money, 
		VTotalPtsEarned money,
		VSessionPlayedID int,
		gtdPayoutReceiptNo int, 
		gtdPrevious money, 
		gtdPost money, 
		gtdDelta money,
		gtTransTotal money,
		SalesCurrencyISOCode nvarchar(3),		-- DE7079
		DefaultCurrencyISOCode nvarchar(3),		-- DE7079
		ExchangeRate money						-- DE7079
		);

--Get Register Sales
insert into #TempRegisterSales
		(GamingDate, TransactionNumber, UnitNumber, PackNumber, DTStamp, Tax, DeviceFee, AmountTendered, 
		PreSalePoints, UnitSerialNumber, TransactiontypeID, StaffID, OperatorID, SaleSuccess,RegisterReceiptID, 
		OriginalReceiptID, 	PlayerID, RegisterDetailID, PackageName, PackagePrice, ReceiptLine, Quantity, DiscountAmount, 
		DiscountPtsPerDollar, TotalPtsEarned, VoidedregisterReceiptID, TotalPtsRedeemed, CardCount,	Price, Qty , 
		CardLvlName, CardLvlID, RegisterDetailItemID, ProductItemName, ProductTypeId, FirstName, LastName, PFirstName, PLastName, 
		DiscountTypeName, TransactionType,  GamingSession, gtdPayoutReceiptNo, gtdPrevious, gtdPost, gtdDelta,
		gtTransTotal
		,SalesCurrencyISOCode, DefaultCurrencyISOCode, ExchangeRate -- DE7079
		,VoidTransactionNumber --TA11132 Retrieve the void transaction number
		)

SELECT RR.GamingDate, RR.TransactionNumber,
        -- Begin DE10482 Unit number calculation
       case when rr.TransactionTypeId = 14 then cast (rr.UnitNumber as nvarchar)
       else (select top 1 case when ulSoldToMachineId is null then cast (ulUnitNumber as nvarchar) else m.ClientIdentifier end 
            from UnlockLog                                                          
            left join machine m on ulSoldToMachineId = m.MachineId
        where ulRegisterReceiptId = rr.RegisterReceiptId
        order by ulId desc) end,
        -- End DE10482
        RR.PackNumber, RR.DTStamp, 
		CASE WHEN RDI.RegisterDetailItemID = (SELECT TOP(1) SubRDI.RegisterDetailItemID 
											 FROM RegisterDetailItems SubRDI
											 WHERE SubRDI.RegisterDetailID = RD.RegisterDetailID 
											 ORDER BY SubRDI.RegisterDetailItemID ASC)
		THEN RD.SalesTaxAmt ELSE 0 END,
		case when rdi.RegisterDetailItemId = (SELECT TOP(1) SubRDI.RegisterDetailItemId
											  FROM RegisterDetail subRD
											    join RegisterDetailItems subRDI on subRD.RegisterDetailId = subRDI.RegisterDetailId
											  WHERE subRD.RegisterReceiptId = rd.RegisterReceiptID 
											  ORDER BY subRDI.RegisterDetailItemID ASC)
		then rr.DeviceFee else 0 end,
--		RR.DeviceFee, 
		RR.AmountTendered, RR.PreSalePoints, 
		-- Begin DE10482 Serial number look up
		(select top 1 case when ulSoldToMachineId is null then ulUnitSerialNumber
		      else m.SerialNumber end
		 from UnlockLog
		    left join Machine m on ulSoldToMachineId = m.MachineId
		 where ulRegisterReceiptId = rr.RegisterReceiptId
		 order by ulId desc)
		 -- End DE10482
		, RR.TransactiontypeID, RR.StaffID, RR.OperatorID,
		RR.SaleSuccess,	RR.RegisterReceiptID, RR.OriginalReceiptID, RR.PlayerID, 
		RD.RegisterDetailID, RD.PackageName, RD.PackagePrice, RD.ReceiptLine, RD.Quantity
		, (ISNULL (RD.DiscountAmount, 0) * RD.Quantity) [DiscountAmount]		-- FIX DE9326
		, RD.DiscountPtsPerDollar, RD.TotalPtsEarned, RD.VoidedregisterReceiptID, RD.TotalPtsRedeemed,
		RDI.CardCount, RDI.Price, RDI.Qty , RDI.CardLvlName, RDI.CardLvlID, RDI.RegisterDetailItemID, RDI.ProductItemName,
		rdi.ProductTypeId,
		S.FirstName, S.LastName, P.FirstName, P.LastName, DiscountTypeName, TransactionType,  SP.GamingSession, 
		gtdPayoutReceiptNo, gtdPrevious, gtdPost, gtdDelta,	gtTransTotal				
		
		-- FIX DE7079
		, RR.SalesCurrencyISOCode, RR.DefaultCurrencyISOCode		
		, case 
			WHEN (@UseExchangeRate = 0) THEN 1.0		-- FIX DE8074
			when RR.DefaultCurrencyISOCode = RR.SalesCurrencyISOCode then 1.0 
		    when RR.DefaultCurrencyISOCode <> RR.SalesCurrencyISOCode then
				(select top(1) cerExchangeRate
					from CurrencyExchangeRate
					join CurrencyExchange on cerCurrencyExchangeID = ceCurrencyExchangeID
					--where ceFromCurrency = RR.SalesCurrencyISOCode
					where ceToCurrency = RR.SalesCurrencyISOCode
					AND cerExchangeDate = RR.GamingDate
					order by cerExchangeDate desc) 					
		  end
		-- END FIX DE7079
		, (select TransactionNumber from RegisterReceipt where RegisterReceiptId = rd.VoidedRegisterReceiptId)
		  
		  
 FROM    Staff S (nolock)
	Left JOIN RegisterReceipt RR (nolock)
		 ON RR.StaffID = S.StaffID
	LEFT JOIN RegisterDetail RD (nolock)
		 ON RR.RegisterReceiptID = RD.RegisterReceiptID
	LEFT JOIN RegisterDetailItems RDI (nolock) 
		ON RD.RegisterDetailID = RDI.RegisterDetailID
	LEFT JOIN  Player P (nolock)
		 ON RR.PlayerID = P.PlayerID 
	LEFT JOIN TransactionType (nolock)
		 ON RR.TransactionTypeID = TransactionType.TransactionTypeID
	LEFT JOIN History.dbo.GameTrans (nolock)
		 ON RR.RegisterReceiptID = gtRegisterReceiptID and RR.TransactiontypeID <> 1
	Left Join History.dbo.GameTransDetail (nolock)
		ON gtGameTransID = gtdGameTransID
	left Join (select distinct SessionPlayedID, GamingSession, GamingDate	--Use derived table to
			from History.dbo.SessionPlayed (nolock)		--eliminate UK duplicates
			) as SP
			on RD.SessionPlayedID = SP.SessionPlayedID
	LEFT JOIN DiscountTypes (nolock)
		ON RD.DiscountTypeID = DiscountTypes.DiscountTypeID
 WHERE  RR.GamingDate >=CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
AND RR.OperatorID = @OperatorID
AND (@StaffID = 0 or RR.StaffID = @StaffID)
and (@Session = 0 or SP.GamingSession = @Session)
and RR.TransactionTypeID <> 2;

--Voids
insert into #TempRegisterSales
		(GamingDate, TransactionNumber, /*UnitNumber,*/ PackNumber, DTStamp, Tax, DeviceFee, AmountTendered, 
		PreSalePoints, /*UnitSerialNumber,*/ TransactiontypeID, StaffID, OperatorID, SaleSuccess,RegisterReceiptID, 
		OriginalReceiptID, 	PlayerID, RegisterDetailID, PackageName, PackagePrice, ReceiptLine, Quantity, DiscountAmount, 
		DiscountPtsPerDollar, TotalPtsEarned,  TotalPtsRedeemed, CardCount,	Price, Qty , 
		CardLvlName, CardLvlID, RegisterDetailItemID, ProductItemName, ProductTypeId, FirstName, LastName, PFirstName, PLastName, 
		DiscountTypeName, TransactionType,  GamingSession, gtdPayoutReceiptNo, gtdPrevious, gtdPost, gtdDelta,
		gtTransTotal,
		VQuantity,  VDiscountAmount,  VTotalPtsRedeemed, VDiscountPtsPerDollar, VTotalPtsEarned,
		VStaffFirstName, VStaffLastName
)

SELECT RR.GamingDate, RR.TransactionNumber,
       (select PackNumber from RegisterReceipt where RegisterReceiptId = rr.OriginalReceiptId)
       , RR.DTStamp, 
		CASE WHEN RDI.RegisterDetailItemID = (SELECT TOP(1) SubRDI.RegisterDetailItemID 
											  FROM RegisterDetailItems SubRDI
											  WHERE SubRDI.RegisterDetailID = RD.RegisterDetailID 
											  ORDER BY SubRDI.RegisterDetailItemID ASC)
		THEN RD.SalesTaxAmt ELSE 0 END,
		0,
		--case when rdi.RegisterDetailItemId = (SELECT TOP(1) SubRDI.RegisterDetailItemId
		--									  FROM RegisterDetail subRD
		--									    join RegisterDetailItems subRDI on subRD.RegisterDetailId = subRDI.RegisterDetailId
		--									  WHERE subRD.RegisterReceiptId = rd.RegisterReceiptID 
		--									  ORDER BY subRDI.RegisterDetailItemID ASC)
		--then rr.DeviceFee else 0 end,
        --RR.DeviceFee, 
		RR.AmountTendered, RR.PreSalePoints, /*RR.UnitSerialNumber,*/ RR.TransactiontypeID, RR.StaffID, RR.OperatorID,
		RR.SaleSuccess,	RR.RegisterReceiptID, RR.OriginalReceiptID, RR.PlayerID, 
		RD.RegisterDetailID, RD.PackageName, RD.PackagePrice, RD.ReceiptLine, RD.Quantity,
		(ISNULL (RD.DiscountAmount, 0) * RD.Quantity) [DiscountAmount]		-- FIX DE9326		
		, RD.DiscountPtsPerDollar, RD.TotalPtsEarned, RD.TotalPtsRedeemed,
		RDI.CardCount, RDI.Price, RDI.Qty , RDI.CardLvlName, RDI.CardLvlID, RDI.RegisterDetailItemID, RDI.ProductItemName, rdi.ProductTypeId,
		(select s1.FirstName from staff as s1 join RegisterReceipt rr1 on s1.StaffId = rr1.StaffId where rr1.RegisterReceiptId = rr.OriginalReceiptId),
		(select s1.LastName from staff as s1 join RegisterReceipt rr1 on s1.StaffId = rr1.StaffId where rr1.RegisterReceiptId = rr.OriginalReceiptId)
	    --S.FirstName, S.LastName
		, P.FirstName, P.LastName, DiscountTypeName, TransactionType,  SP.GamingSession, 
		gtdPayoutReceiptNo, gtdPrevious, gtdPost, gtdDelta,	gtTransTotal,
		RD.Quantity, 
		(ISNULL (RD.DiscountAmount, 0) * RD.Quantity) [VDiscountAmount]		-- FIX DE9326
		, RD.TotalPtsRedeemed, RD.DiscountPtsPerDollar, RD.TotalPtsEarned,
		s.FirstName, s.LastName

 FROM    Staff S (nolock)
	Left JOIN RegisterReceipt RR (nolock)
		 ON RR.StaffID = S.StaffID 
	LEFT JOIN RegisterDetail RD (nolock)
		 ON RR.RegisterReceiptID = RD.VoidedRegisterReceiptID
	LEFT JOIN RegisterDetailItems RDI (nolock) 
		ON RD.RegisterDetailID = RDI.RegisterDetailID
	LEFT JOIN  Player P (nolock)
		 ON RR.PlayerID = P.PlayerID 
	LEFT JOIN TransactionType (nolock)
		 ON RR.TransactionTypeID = TransactionType.TransactionTypeID
	LEFT JOIN History.dbo.GameTrans (nolock)
		 ON RR.RegisterReceiptID = gtRegisterReceiptID and RR.TransactiontypeID <> 1
	Left Join History.dbo.GameTransDetail (nolock)
		ON gtGameTransID = gtdGameTransID
	left Join (select distinct SessionPlayedID, GamingSession, GamingDate	--Use derived table to
			from History.dbo.SessionPlayed (nolock)		--eliminate UK duplicates
			) as SP
			on RD.SessionPlayedID = SP.SessionPlayedID
	LEFT JOIN DiscountTypes (nolock)
		ON RD.DiscountTypeID = DiscountTypes.DiscountTypeID
	
 WHERE  RR.GamingDate >=CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
AND RR.OperatorID = @OperatorID
AND (@StaffID = 0 or @StaffId in (select StaffId from RegisterReceipt where RegisterReceiptId = rr.OriginalReceiptId))
and (@Session = 0 or SP.GamingSession = @Session)
and RR.TransactiontypeID = 2;

UPDATE #TempRegisterSales
SET OriginalTransactionNumber = rr.TransactionNumber
	,DeviceFee = 	case when trs.RegisterDetailItemId = (SELECT TOP(1) SubRDI.RegisterDetailItemId
											  FROM RegisterDetail subRD
											    join RegisterDetailItems subRDI on subRD.RegisterDetailId = subRDI.RegisterDetailId
											  WHERE subRD.RegisterReceiptId = rd.RegisterReceiptID 
											  ORDER BY subRDI.RegisterDetailItemID ASC)
		then rr.DeviceFee else 0 end
--    ,DeviceFee = rr.DeviceFee --DE9944
FROM #TempRegisterSales trs
    JOIN RegisterReceipt rr ON (trs.OriginalReceiptID = rr.RegisterReceiptID)
    join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
    join RegisterDetailItems rdi on rd.RegisterDetailId = rdi.RegisterDetailId
WHERE trs.OriginalReceiptID IS NOT NULL;

UPDATE #TempRegisterSales
SET DiscountAmount = DiscountAmount * -1
WHERE TransactiontypeID = 3

UPDATE #TempRegisterSales
SET SalesCurrencyISOCode = (SELECT MIN(SalesCurrencyIsoCode) FROM #TempRegisterSales WHERE TransactionNumber = trs.OriginalTransactionNumber),
	DefaultCurrencyISOCode = (SELECT MIN(DefaultCurrencyISOCode) FROM #TempRegisterSales WHERE TransactionNumber = trs.OriginalTransactionNumber),
	ExchangeRate = (SELECT MIN(ExchangeRate) FROM #TempRegisterSales WHERE TransactionNumber = trs.OriginalTransactionNumber)
FROM #TempRegisterSales trs
WHERE SalesCurrencyISOCode IS NULL
AND DefaultCurrencyISOCode IS NULL
AND ExchangeRate IS NULL

if exists (select staffid from #TempRegisterSales  where StaffID  = @StaffID)
begin 
    select * from #TempRegisterSales
end
else 
begin
    insert into #TempRegisterSales
    (staffId, LastName, FirstName, GamingSession)
    select StaffID, LastName, FirstName, @Session
    from Staff
    where StaffID = @StaffID
 
    select * from #TempRegisterSales;   
end 

Drop Table #TempRegisterSales;

SET NOCOUNT OFF














GO

