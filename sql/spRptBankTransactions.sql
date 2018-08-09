USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBankTransactions]    Script Date: 12/12/2013 15:02:08 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBankTransactions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBankTransactions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBankTransactions]    Script Date: 12/12/2013 15:02:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <12/06/2013>
-- Description:	<Bank Transactions - Detailed listing of all bank transctions
--               storred procedure is based off of spGetCashTransactionList>
-- =============================================

CREATE PROCEDURE [dbo].[spRptBankTransactions]
	
	@StartDate smalldatetime,
	@Session int,
	@OperatorID int

AS

BEGIN

	SET NOCOUNT ON;

Declare @BankResults table (
	SrcBankTypeID int,
	DstBankTypeID int,
	SessionNo int,
	SrcBankStaffID int,
	DstBankStaffID int,
	TransID int,
	TransactionTotal money,
	TransactionTypeID int,
	OriginalTransTypeID int,
	CreatedByStaffID int,
	GamingDate smalldatetime,
	IsVoid int,
	SrcBankName nvarchar(32),
	DstBankName nvarchar(32),
	DTStamp datetime)

Declare @Results table (
	BankTypeID int,
	BankStaffID int,
	BankStaffName nvarchar(32),
	TransactionTypeID int,
	TransactionType nvarchar(32),
	DstBankTypeID int,
	DstBankStaffID int,
	DstBankStaffName nvarchar(32),
	CreatedByStaffID int,
	CreatedByStaffName nvarchar(32),
	IncreaseAmount money,
	DecreaseAmount money,
	DTStamp datetime,
	SessionNo int
)

declare @DefaultCurrency as nvarchar(3)

select top (1) @DefaultCurrency = crhISOCode
from currencyheader
where crhIsDefault = 1

insert into @BankResults (
	SrcBankTypeID,
	DstBankTypeID,
	SessionNo,
	SrcBankStaffID,
	DstBankStaffID,
	TransID,
	TransactionTotal,
	TransactionTypeID,
	OriginalTransTypeID,
	CreatedByStaffID,
	GamingDate,
	IsVoid,
	SrcBankName,
	DstBankName,
	DTStamp)
select
	SrcBankTypeID = case when ct2.ctrTransactionTypeID IS NULL then sb.bkBankTypeID else db.bkBankTypeID end,
	DstBankTypeID = case when ct2.ctrTransactionTypeID IS NULL then db.bkBankTypeID else sb.bkBankTypeID end,
	SessionNo	= ct1.ctrGamingSession,
	SrcBankStaffID = case when ct2.ctrTransactionTypeID IS NULL then sb.bkStaffID else db.bkStaffID end,
	DstBankStaffID = case when ct2.ctrTransactionTypeID IS NULL then db.bkStaffID else sb.bkStaffID end,
	TransID		= ct1.ctrCashTransactionID,
	TransactionTotal = (SUM (ctrdTotal) * ISNULL((select cerExchangeRate from CurrencyExchangeRate
											join CurrencyExchange on ceCurrencyExchangeID = cerCurrencyExchangeID
											where ceToCurrency = @DefaultCurrency and
											ceFromCurrency = ctrdISOCode and
											cerExchangeDate = @StartDate), 1)),
	TransactionTypeID	= ct1.ctrTransactionTypeID,
	OriginalTransTypeID	= ISNULL(ct2.ctrTransactionTypeID, 0),
	CreatedByStaffID	= ct1.ctrTransactionStaffID,
	GamingDate			= ct1.ctrGamingDate,
	IsVoid = CASE WHEN (SELECT COUNT(*)
						  FROM CashTransaction ct WITH (NOLOCK)
						 WHERE ct.ctrOriginalCashTransactionID = ct1.ctrCashTransactionID) = 1
				  THEN 1
				  ELSE 0
				  END,
	SrcBankName = case when ct2.ctrTransactionTypeID IS NULL then sb.bkBankName else db.bkBankName end,
	DstBankName = case when ct2.ctrTransactionTypeID IS NULL then db.bkBankName else sb.bkBankName end,
	DTStamp = ct1.ctrCashTransactionDate
from CashTransaction ct1 with (nolock)
left join CashTransaction ct2 with (nolock)
	on ct1.ctrOriginalCashTransactionID = ct2.ctrCashTransactionID
join CashTransactionDetail with (nolock)
	on ct1.ctrCashTransactionID = ctrdCashTransactionID
left join Bank sb with (nolock)
	on ct1.ctrSrcBankID = sb.bkBankID
left join Bank db with (nolock)
	on ct1.ctrDestBankID = db.bkBankID
where ct1.ctrGamingDate = @StartDate and
	(ct1.ctrGamingSession = @Session or @Session = 0) and
	(sb.bkOperatorID = @OperatorID or db.bkOperatorID = @OperatorID )
GROUP BY sb.bkBankTypeID, db.bkBankTypeID, ct1.ctrSrcBankID, ct1.ctrDestBankID, ct1.ctrGamingSession, sb.bkStaffID, db.bkStaffID, ct1.ctrCashTransactionID, ct1.ctrTransactionTypeID, 
         ct2.ctrTransactionTypeID, ct1.ctrTransactionStaffID, sb.bkBankName, db.bkBankName, ctrdISOCode, ct1.ctrGamingDate, ct1.ctrCashTransactionDate


-- Insert transactions from staffs bank (decreases)
Insert into @Results
Select	SrcBankTypeID,
		SrcBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = SrcBankStaffID), br.DstBankName),
		br.TransactionTypeID,
		TransactionType,
		DstBankTypeID,
		DstBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = DstBankStaffID), br.SrcBankName),
		CreatedByStaffID,
		(Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = CreatedByStaffID) as CreatedStaffName,
		0,
		Sum(TransactionTotal),
		DTStamp,
		SessionNo
From @BankResults br join TransactionType tt on br.TransactionTypeID = tt.TransactionTypeID
Where tt.TransactionTypeID <> 39
Group By SrcBankTypeID, br.TransactionTypeID, TransactionType, SrcBankStaffID, DstBankStaffID, CreatedByStaffID, DTStamp, SrcBankName, DstBankName, DstBankTypeID, SessionNo

-- Insert voided from transactions
Insert into @Results
Select	SrcBankTypeID,
		SrcBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = SrcBankStaffID), br.DstBankName),
		br.TransactionTypeID,
		TransactionType,
		DstBankTypeID,
		DstBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = DstBankStaffID), br.SrcBankName),
		CreatedByStaffID,
		(Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = CreatedByStaffID) as CreatedStaffName,
		Sum(TransactionTotal),
		0,
		DTStamp,
		SessionNo
From @BankResults br join TransactionType tt on br.TransactionTypeID = tt.TransactionTypeID
Where tt.TransactionTypeID = 39
Group By SrcBankTypeID, br.TransactionTypeID, TransactionType, SrcBankStaffID, DstBankStaffID, CreatedByStaffID, DTStamp, SrcBankName, DstBankName, DstBankTypeID, SessionNo

-- Insert transaction to staffs bank (increases)
Insert into @Results
Select	DstBankTypeID,
		DstBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = DstBankStaffID), br.SrcBankName),
		br.TransactionTypeID,
		TransactionType,
		SrcBankTypeID,
		SrcBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = SrcBankStaffID), br.DstBankName),
		CreatedByStaffID,
		(Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = CreatedByStaffID) as CreatedStaffName,
		Sum(TransactionTotal),
		0,
		DTStamp,
		SessionNo
From @BankResults br join TransactionType tt on br.TransactionTypeID = tt.TransactionTypeID
Where tt.TransactionTypeID <> 39
Group By DstBankTypeID, br.TransactionTypeID, TransactionType, SrcBankStaffID, DstBankStaffID, CreatedByStaffID, DTStamp, DstBankName, SrcBankName, SrcBankTypeID, SessionNo

-- Insert voided transactions to
Insert into @Results
Select	DstBankTypeID,
		DstBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = DstBankStaffID), br.SrcBankName),
		br.TransactionTypeID,
		TransactionType,
		SrcBankTypeID,
		SrcBankStaffID,
		Isnull((Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = SrcBankStaffID), br.DstBankName),
		CreatedByStaffID,
		(Select s.FirstName + SPACE(1) + s.LastName
		From Staff s
		Where s.StaffID = CreatedByStaffID) as CreatedStaffName,
		0,
		Sum(TransactionTotal),
		DTStamp,
		SessionNO
From @BankResults br join TransactionType tt on br.TransactionTypeID = tt.TransactionTypeID
Where tt.TransactionTypeID = 39
Group By DstBankTypeID, br.TransactionTypeID, TransactionType, SrcBankStaffID, DstBankStaffID, CreatedByStaffID, DTStamp, DstBankName, SrcBankName, SrcBankTypeID, SessionNo

Select *
From @Results
Order By BankStaffName, DTStamp;

End


GO

