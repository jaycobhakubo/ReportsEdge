USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicSessionSummaryPOS]    Script Date: 04/25/2014 11:41:46 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicSessionSummaryPOS]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicSessionSummaryPOS]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicSessionSummaryPOS]    Script Date: 04/25/2014 11:41:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <12/11/2013>
-- Description:	<Electronic Session Summary - Reports the Point of Sale transaction history to meet North Dakotas requirements
-- 1. Sequential Transaction Number
-- 2. Device Serial Number
-- 3. Type of Transaction
-- 4. Time of Transaction
-- 5. Number of electronic bingo card images downloaded
-- 6. Selling price of a card or package
-- 7. Receipt Number>
-- 2014.04.25 tmp: DE11723 - If the sale fails then set the sales total to 0.
-- =============================================
CREATE PROCEDURE [dbo].[spRptElectronicSessionSummaryPOS]
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@Session	AS INT
AS
BEGIN

	SET NOCOUNT ON;

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
		PackNumber,
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
        Case When p.TransactionTypeID = 1 Then (isnull(Sum(rd.Quantity * rd.PackagePrice), 0) + isnull(Sum(rd.Quantity * rd.DiscountAmount), 0) + isnull(Sum(rd.Quantity * rd.SalesTaxAmt), 0))
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
Join RegisterDetail rd on rd.RegisterReceiptID = fes.OriginalRegisterReceiptID
Join RegisterReceipt r on r.RegisterReceiptID = fes.OriginalRegisterReceiptID
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

Select	RowID,
		TransactionNumber,
		MachineID,
		TransactionType,
		DTStamp,
		Case When PackNumber = 0 Then null
			When PackNumber <> 0 Then PackNumber
			End as PackNumber,
		GamingSession,
		SessionPlayedID,
		CardsSold,
		EleSalesAmount,
		Case When TransactionType = 'Sale Failed' Then 0  --DE11723
			Else DeviceFee + RegisterSales End as SalesTotal --DE11723
From @Results
Order By TransactionNumber
END






GO

