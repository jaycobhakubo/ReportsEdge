USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptNorthDakotaSessionSummary]    Script Date: 09/17/2015 16:36:44 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptNorthDakotaSessionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptNorthDakotaSessionSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptNorthDakotaSessionSummary]    Script Date: 09/17/2015 16:36:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<FortuNet>
-- Create date: <8/19/2015>
-- Description:	<North Dakota Session Summary - Reports the sales transaction history to meet North Dakotas requirements
-- For each transaction list:
-- 1. For server based accounts, account number
-- 2. For downloaded devices, nonresetable consecutive transaction number starting with one, for each device
-- 3. For downloaded devices, device serial number
-- 4. Type of transaction (sale or void) --- Our system also supports Transfers
-- 5. Time of transaction
-- 6. Receipt Number
-- 7. For voided transactions, dollar value of the void
-- 8. Selling price of each card or package, dollar value of credits sold, dollar value or unplayed credits cashed out, and gross proceeds.
-- =============================================
CREATE PROCEDURE [dbo].[spRptNorthDakotaSessionSummary]
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@Session	AS INT
AS
BEGIN

	SET NOCOUNT ON;

---- For Testing ---------------------------------------------
--Declare @OperatorID	AS INT,
--	@StartDate	AS DATETIME,
--	@Session	AS INT
	

--Set @OperatorID = 1
--Set @StartDate = '08/18/2015'
--Set @Session = 1	

Declare @POSTransactions table
(
		RowID int,
		SoldFromMachineID int,
		RegisterReceiptID int,
		OriginalReceiptID int,
		TransactionNumber int,
		ClientIdentifier nvarchar(64),
		SerialNumber nvarchar(64),
		TransactionTypeID int,
		TransactionType nvarchar(64),
		PackNumber int,
		StaffID int,
		OperatorID int,
		GamingDate smalldatetime,
		DTStamp datetime,
		DeviceFee money,
		TransferReceiptID int
)
Insert into @POSTransactions
Select	RowID,
		SoldFromMachineID,
		RegisterReceiptID,
		OriginalReceiptID,
		TransactionNumber,
		ClientIdentifier,
		SerialNumber,
		TransactionTypeID,
		TransactionType,
		Case when PackNumber = 0 Then null Else PackNumber End,
		StaffID,
		OperatorID,
		GamingDate,
		DTStamp,
		DeviceFee,
		Null
From view_GetPOSMachineHistory
Where GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)

-- Update the transfer id with the register receipt id from the original sale.

declare @RegisterReceiptID int,
	@OriginalReceiptID int	

declare TransferCursor cursor for
select RegisterReceiptID, OriginalReceiptID from @POSTransactions

open TransferCursor
fetch next from TransferCursor into @RegisterReceiptID, @OriginalReceiptID
while @@fetch_status = 0
begin
	while exists (select * from @POSTransactions where RegisterReceiptID = @OriginalReceiptID)
	begin
		update @POSTransactions
		set TransferReceiptID = (select RegisterReceiptID
		                      from @POSTransactions
		                      where RegisterReceiptID = @OriginalReceiptID)
		where RegisterReceiptID = @RegisterReceiptID

		select @OriginalReceiptID = OriginalReceiptID
		from @POSTransactions
		where RegisterReceiptID = @OriginalReceiptID
	end

	fetch next from TransferCursor into @RegisterReceiptID, @OriginalReceiptID
end

close TransferCursor
deallocate TransferCursor

--Select *
--From @POSTransactions

Declare @Results table
(
		RowID int,
		TransactionNumber int,
		MachineID nvarchar(64),
		TransactionTypeID int,
		TransactionType nvarchar(64),
		DTStamp DateTime,
		DeviceFee money,
		PackNumber int,
		GamingSession int,
		SessionPlayedID int,
		CardsSold int,
		EleSalesAmount money,
		RegisterSales money
)
Insert @Results
Select	p.RowID,
		p.TransactionNumber,
		Isnull(p.SerialNumber, p.ClientIdentifier) as MachineID,
		p.TransactionTypeID,
		p.TransactionType,
		p.DTStamp,
		p.DeviceFee,
		p.PackNumber,
		sp.GamingSession,
		sp.SessionPlayedID,
		fes.CardsSold,
		fes.SalesAmount,
        Case When p.TransactionTypeID = 1 and p.TransactionType <> 'Sale Failed' Then (isnull(Sum(rd.Quantity * rd.PackagePrice), 0) + isnull(Sum(rd.Quantity * rd.DiscountAmount), 0) + isnull(Sum(rd.Quantity * rd.SalesTaxAmt), 0))
			When p.TransactionTypeID = 1 and p.TransactionType = 'Sale Failed' Then 0
			When p.TransactionTypeID = 3 Then (isnull(Sum(-1 * rd.Quantity * rd.PackagePrice), 0) + isnull(Sum(rd.Quantity * rd.DiscountAmount), 0) + isnull(Sum(rd.Quantity * rd.SalesTaxAmt), 0))
			End as RegisterSales
From @POSTransactions p Left Join FindElectronicSales (@OperatorID, @StartDate, @StartDate, @Session) fes on p.TransactionNumber = fes.ReceiptNumber
Join RegisterDetail rd on rd.RegisterReceiptID = p.RegisterReceiptID
Left Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where (p.OperatorID = @OperatorID or p.OperatorID = 0)
And (sp.GamingSession = @Session or @Session = 0)
And (p.TransactionTypeID <> 2 --- Insert everything but Sale Void transactions
Or p.TransactionTypeID <> 14) --- Transfers
Group By p.TransactionNumber, p.RowID, p.SerialNumber, p.ClientIdentifier, p.TransactionType, p.DTStamp, p.DeviceFee, p.PackNumber, fes.CardsSold, fes.SalesAmount, p.TransactionTypeID, sp.GamingSession, sp.SessionPlayedID
Order By p.TransactionNumber


----- Insert Void Transactions
Insert @Results
Select	p.RowID,
		p.TransactionNumber,
		Isnull(p.SerialNumber, p.ClientIdentifier) as MachineID,
		p.TransactionTypeID,
		p.TransactionType,
		p.DTStamp,
		(-1 * r.DeviceFee),
		fes.PackNumber,
		sp.GamingSession,
		sp.SessionPlayedID,
		(-1 * fes.CardsSold),
		(-1 * fes.SalesAmount),
        (isnull(Sum(-1 * rd.Quantity * rd.PackagePrice), 0) + isnull(Sum(rd.Quantity * rd.DiscountAmount), 0) + isnull(Sum(rd.Quantity * rd.SalesTaxAmt), 0)) as RegisterSales
From @POSTransactions p Left Join FindElectronicSales (@OperatorID, @StartDate, @StartDate, @Session) fes on p.TransactionNumber = fes.ReceiptNumber
Join RegisterDetail rd on rd.RegisterReceiptID = p.OriginalReceiptID
Left Join RegisterReceipt r on r.RegisterReceiptID = fes.OriginalRegisterReceiptID
Left Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where (p.OperatorID = @OperatorID or p.OperatorID = 0)
And (sp.GamingSession = @Session or @Session = 0)
And p.TransactionTypeID = 2
Group By p.TransactionNumber, p.RowID, p.SerialNumber, p.ClientIdentifier, p.TransactionType, p.DTStamp, r.DeviceFee, fes.PackNumber, fes.CardsSold, fes.SalesAmount, p.TransactionTypeID, sp.GamingSession, sp.SessionPlayedID
Order By p.TransactionNumber

----- Insert Transfer Transactions
Insert @Results
Select	p.RowID,
		p.TransactionNumber,
		Isnull(p.SerialNumber, p.ClientIdentifier) as MachineID,
		p.TransactionTypeID,
		p.TransactionType,
		p.DTStamp,
		r.DeviceFee,
		r.PackNumber,
		sp.GamingSession,
		sp.SessionPlayedID,
		Null,
		Null,
        Null
From @POSTransactions p Join RegisterReceipt r on p.TransferReceiptID = r.RegisterReceiptID
Join RegisterDetail rd on rd.RegisterReceiptID = r.RegisterReceiptID
Left Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Where (p.OperatorID = @OperatorID or p.OperatorID = 0)
And (sp.GamingSession = @Session or @Session = 0)
And p.TransactionTypeID = 14
Group By p.TransactionNumber, p.RowID, p.SerialNumber, p.ClientIdentifier, p.TransactionType, p.DTStamp, r.DeviceFee, r.PackNumber, p.TransactionTypeID, sp.GamingSession, sp.SessionPlayedID
Order By p.TransactionNumber


--- Insert Crate Loaded Device Transactions --------------------------------------------------------------------------------------------------
Declare @CrateLoadedPreHistory table
(
	RegisterReceiptID int,
	OriginalReceiptID int,
	DeviceID int,
	TransactionNumber int,
	TransactionTypeID int,
	TransType nvarchar(64),
	UnitNumber smallint,
	UnitSerialNumber nvarchar(15),
	PackNumber int,
	OperatorID int,
	GamingDate SmallDateTime,
	DTStamp DateTime,
	TransferReceiptID int
)
Insert into @CrateLoadedPreHistory

Select	rr.RegisterReceiptID,
		rr.OriginalReceiptID,
		Isnull(rr.DeviceID, (Select rr2.DeviceID from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)) as DeviceID,
		rr.TransactionNumber,
		rr.TransactionTypeID,
		Case When rr.TransactionTypeID = 1 Then 'Pack Entered'
			 When rr.TransactionTypeID = 2 Then 'Pack Removed'
				Else 'Pack Entered' End as TransType,				
		Case When rr.TransactionTypeID = 2 Then (Select rr2.UnitNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
				Else rr.UnitNumber End as UnitNumber,
		Case When rr.TransactionTypeID = 2 Then (Select rr2.UnitSerialNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
				Else rr.UnitSerialNumber End as UnitSerialNumber,
		Case When rr.TransactionTypeID = 2 Then (Select rr2.PackNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
			 When rr.TransactionTypeID = 14 Then (Select rr2.PackNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr. OriginalReceiptID)	
				Else rr.PackNumber End as PackNumber,
		rr.OperatorID,
		rr.GamingDate,
		rr.DTStamp,
		null
From RegisterReceipt rr

-- Update transfer transactions with the original receipt number from the original sale
--declare @RegisterReceiptID int,
--	@OriginalReceiptID int	

declare TransferCursor cursor for
select RegisterReceiptID, OriginalReceiptID from @CrateLoadedPreHistory Where GamingDate = @StartDate

open TransferCursor
fetch next from TransferCursor into @RegisterReceiptID, @OriginalReceiptID
while @@fetch_status = 0
begin
	while exists (select * from @CrateLoadedPreHistory where RegisterReceiptID = @OriginalReceiptID And GamingDate = @StartDate)
	begin
		update @CrateLoadedPreHistory
		set TransferReceiptID = (select RegisterReceiptID
		                      from @CrateLoadedPreHistory
		                      where RegisterReceiptID = @OriginalReceiptID
							  And GamingDate = @StartDate)
		where RegisterReceiptID = @RegisterReceiptID

		select @OriginalReceiptID = OriginalReceiptID
		from @CrateLoadedPreHistory
		where RegisterReceiptID = @OriginalReceiptID
	end

	fetch next from TransferCursor into @RegisterReceiptID, @OriginalReceiptID
end

close TransferCursor
deallocate TransferCursor


--- Insert record(s) for the device the package was transferred from
Insert @CrateLoadedPreHistory
Select	rr.RegisterReceiptID,
		rr.OriginalReceiptID,
		rr.DeviceID,
		rr.TransactionNumber,
		rr.TransactionTypeID,
		Case When rr.TransactionTypeID = 1 Then 'Pack Entered'
			 When rr.TransactionTypeID = 2 Then 'Pack Removed'
				Else 'Pack Removed' End as TransType,
		Case When rr.TransactionTypeID = 14 Then (Select rr2.UnitNumber From RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
			Else rr.UnitNumber End as UnitNumber,
		Case When rr.TransactionTypeID = 14 Then (Select rr2.UnitSerialNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
			Else rr.UnitSerialNumber End as UnitNumber,
		Case When rr.TransactionTypeID = 14 Then (Select rr2.PackNumber from RegisterReceipt rr2 where rr2.RegisterReceiptID = rr.OriginalReceiptID)
			Else rr.PackNumber End as PackNumnber,
		rr.OperatorID,
		rr.GamingDate,
		rr.DTStamp,
		Null
From RegisterReceipt rr 
Where rr.OriginalReceiptID = (Select rr2.RegisterReceiptID From RegisterReceipt rr2 Where rr2.RegisterReceiptID = rr.OriginalReceiptID)
And rr.TransactionTypeID = 14

--- Temp table to store transaction history to assign sequential number starting at 1 for each crate loaded device
Declare @CrateLoadedTransHistory table
(
	RowID int,
	RegisterReceiptID int,
	OriginalReceiptID int,
	DeviceID int,
	TransactionNumber int,
	TransactionTypeID int,
	TransactionType nvarchar(64),
	UnitNumber smallint,
	UnitSerialNumber nvarchar(15),
	PackNumber int,
	OperatorID int,
	GamingDate SmallDateTime,
	DTStamp DateTime,
	TransferReceiptID int
)
Insert into @CrateLoadedTransHistory
Select	ROW_NUMBER() Over(Partition By UnitSerialNumber Order By TransactionNumber) as RowID,
		RegisterReceiptID,
		OriginalReceiptID,
		DeviceID,
		TransactionNumber,
		TransactionTypeID,
		TransType,
	    UnitNumber,
		UnitSerialNumber,
		PackNumber,
		OperatorID,
		GamingDate,
		DTStamp,
		TransferReceiptID
From @CrateLoadedPreHistory 
Where DeviceID in (1, 2)

--- Resultset --------------------------------------------------------

Select  r.TransactionNumber,
		r.TransactionType,
		r.DTStamp,
		isnull(r.DeviceFee, 0) as DeviceFee,
		r.PackNumber as PackNumber,
		r.GamingSession,
		r.SessionPlayedID,
		r.CardsSold as CardsSold,
		r.EleSalesAmount as EleSalesAmount,
		isnull(r.RegisterSales, 0) + ISNULL(r.DeviceFee, 0) as SalesTotal,
		ch.RowID,
		ch.UnitSerialNumber
From @Results r left join @CrateLoadedTransHistory ch on r.TransactionNumber = ch.TransactionNumber and ch.UnitSerialNumber is not null
order by TransactionNumber, UnitSerialNumber

End




GO

