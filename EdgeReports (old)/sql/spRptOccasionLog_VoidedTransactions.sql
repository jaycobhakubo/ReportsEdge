USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_VoidedTransactions]    Script Date: 12/04/2012 14:42:53 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionLog_VoidedTransactions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionLog_VoidedTransactions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_VoidedTransactions]    Script Date: 12/04/2012 14:42:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <11/27/2012>
-- Description:	<End of Occasion Log Voided Transactions for Texas>
-- =============================================

CREATE PROCEDURE [dbo].[spRptOccasionLog_VoidedTransactions]
(
@OperatorID	as	int,
@StartDate	as	datetime,
@Session	as	int
)
AS
BEGIN
	
	SET NOCOUNT ON;
	
Declare @EndDate as DateTime
Set @EndDate = @StartDate
	
--Test values
--Set @OperatorID = 1
--Set @StartDate = '04/04/2012'
--Set @Session = 1

Declare @Results Table
(
	VoidTransactionNumber Int,
	VoidAmount Money,
	OriginalReceiptID Int,
	VoidDT DateTime,
	OriginalTransactionNumber Int
)

Insert Into @Results
(
	VoidTransactionNumber,
	VoidAmount,
	OriginalReceiptID,
	VoidDT 
)
SELECT	rr.TransactionNumber,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		rr.OriginalReceiptID,
		rr.DTStamp	
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.OriginalReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And sp.GamingSession = @Session
	And rr.SaleSuccess = 1
	And rr.TransactionTypeID = 2
	And rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID in (1, 2, 3, 4, 5, 16, 17)
GROUP BY rr.TransactionNumber, rr.OriginalReceiptID, rr.DTStamp

Update @Results
Set OriginalTransactionNumber = RR.TransactionNumber
From RegisterReceipt RR Join @Results RS on RR.RegisterReceiptID = RS.OriginalReceiptID 

Select *
From @Results
End


GO


