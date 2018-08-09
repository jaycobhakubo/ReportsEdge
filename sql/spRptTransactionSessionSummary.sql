USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTransactionSessionSummary]    Script Date: 12/31/2013 20:18:12 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptTransactionSessionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptTransactionSessionSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTransactionSessionSummary]    Script Date: 12/31/2013 20:18:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <12/11/2013>
-- Description:	<Transaction Session Summary - Reports electronic transaction history to meet North Dakotas requirements
-- 1. Sequential Transaction Number
-- 2. Device Serial Number
-- 3. Type of Transaction
-- 4. Time of Transaction
-- 5. Number of electronic bingo card images downloaded
-- 6. Selling price of a card or package
-- 7. Receipt Number>
-- =============================================
CREATE PROCEDURE [dbo].[spRptTransactionSessionSummary]
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@Session	AS INT
AS
BEGIN

	SET NOCOUNT ON;

Declare @Results table
(
	RowID int,
	GamingDate datetime,
	DeviceID int,
	PackNumber int,
	UnitNumber int,
	UnitSerialNumber nvarchar(64),
	RegisterReceiptID int,
	OriginalReceiptID int,
	TransactionNumber int,
	SoldToMachineID int,
	TransDate datetime,
	TransType nvarchar(32),
	TransactionTypeID int,
	TransferReceiptID int
)

--- Insert Network Device Transactions --------------------------------------------------------------------------------------------------------
Insert into @Results
Select  RowID,
		ulGamingDate,
		ulDeviceID,
		ulPackNumber,
		ulUnitNumber,
		ulUnitSerialNumber,
		ulRegisterReceiptID,
		Null,
		TransactionNumber,
		ulSoldToMachineID,
		DTStamp,
		TransactionType,
		Null,
		Null
From view_GetMachineHistory
Where ulGamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)

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
declare @RegisterReceiptID int,
	@OriginalReceiptID int	

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

-- Insert the crate loaded transactions into the results table
Insert into @Results
Select	RowID,
		GamingDate,
		DeviceID,
		PackNumber,
		UnitNumber,
		UnitSerialNumber,
		RegisterReceiptID,
		OriginalReceiptID,
		TransactionNumber,
		0,
		DTStamp,
		TransactionType,
		TransactionTypeID,
		TransferReceiptID
From @CrateLoadedTransHistory c
Where GamingDate = @StartDate

Update @Results 
Set TransferReceiptID = c.TransferReceiptID
From @CrateLoadedTransHistory c join @Results r on (c.RegisterReceiptID = r.RegisterReceiptID and c.OriginalReceiptID = r.OriginalReceiptID)
Where r.TransferReceiptID is Null


-- Find the number of cards sold and electronic sales amount for each package
Declare @ElectronicResults table
(
		RegisterReceiptID int,
		ReceiptNumber int,
		OriginalReceiptID int,
		PackNumber int,
		GamingDate DateTime,
		GamingSession int,
		SessionPlayedID int,
		DeviceName nvarchar(32),
		MachineID int,
		ClientIdentifier nvarchar(64),
		CardsSold int,
		SalesAmount money
)
Insert into @ElectronicResults
Select	RegisterReceiptID,
		ReceiptNumber,
		OriginalRegisterReceiptID,
		PackNumber,
		GamingDate,
		GamingSession,
		SessionPlayedID,
		DeviceName,
		MachineID,
		isnull(ClientIdentifier, SerialNumber),
		CardsSold,
		SalesAmount
From FindElectronicSales (@OperatorID, @StartDate, @StartDate, @Session)

--- Insert Transfer Transactions for Traveler and Tracker
Insert into @ElectronicResults
Select	r.RegisterReceiptID,
		r.TransactionNumber,
		r.OriginalReceiptID,
		fes.PackNumber,
		fes.GamingDate,
		GamingSession,
		SessionPlayedID,
		DeviceName,
		MachineID,
		r.UnitSerialNumber,
		CardsSold,
		SalesAmount
From FindElectronicSales (@OperatorID, @StartDate, @StartDate, @Session) fes join @Results r on fes.RegisterReceiptID = r.TransferReceiptID
Where r.TransactionTypeID = 14
And r.DeviceID in (1, 2)

--Return the results

Select  r.RowID,
		er.PackNumber,
		Case
			When r.UnitSerialNumber = 0 Then er.ClientIdentifier
			When r.UnitSerialNumber = ' ' Then er.ClientIdentifier
				Else r.UnitSerialNumber
			End as SerialNumber,
		r.TransDate,
		TransType,
		er.GamingSession,
		er.SessionPlayedID,
		Case
			When r.TransactionTypeID = 2 Then (-1 * er.CardsSold)
			When r.TransactionTypeID = 14 and r.TransType = 'Pack Removed' Then (-1 * er.CardsSold)
				Else er.CardsSold
			End as CardsSold,
		Case
			When r.TransactionTypeID = 2 Then (-1 * er.SalesAmount)
			When r.TransactionTypeID = 14 and r.TransType = 'Pack Removed' Then (-1 * er.SalesAmount)
				Else er.SalesAmount
			End as SalesAmount,
		r.TransactionNumber
From @Results r join @ElectronicResults er on ((r.RegisterReceiptID = er.RegisterReceiptID and r.UnitSerialNumber = er.ClientIdentifier and r.DeviceID in (1, 2))
												 or (r.TransactionNumber = er.ReceiptNumber and r.DeviceID > 2))
													
Where (er.GamingSession = @Session or @Session = 0)
Group By GamingSession, TransactionNumber, UnitSerialNumber, RowID, SessionPlayedID, CardsSold, SalesAmount, er.PackNumber,
				TransDate, TransType, ClientIdentifier, TransactionTypeID, r.RegisterReceiptID 
Order By TransactionNumber, SerialNumber, RowID

END


GO

