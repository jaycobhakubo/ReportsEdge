USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_Transactions]    Script Date: 12/10/2012 14:55:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionLog_Transactions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionLog_Transactions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionLog_Transactions]    Script Date: 12/10/2012 14:55:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<FortuNet>
-- Create date: <11/27/2012>
-- Description:	<Sequential listing of transaction numbers for the End of Occasion Log for Texas>
-- =============================================
CREATE PROCEDURE [dbo].[spRptOccasionLog_Transactions]
(
@OperatorID Int,
@StartDate DateTime,
@Session Int
)

--For testing
--Set @OperatorID = 1
--Set @GamingDate = '11/26/2012'
--Set @Session = 1

AS
BEGIN
	
SET NOCOUNT ON;

Declare @EndDate as DateTime
Set @EndDate = @StartDate

Declare @Results Table
(
RegisterReceiptID Int,
TransactionNumber Int,
TransactionType nvarchar(64),
VoidedRegisterReceiptID Int
)


-- Insert the sales transactions
Insert into @Results
(
RegisterReceiptID,
TransactionNumber,
TransactionType,
VoidedRegisterReceiptID
)
Select rr.RegisterReceiptID,
	rr.TransactionNumber,
	tt.TransactionType,
	rd.VoidedRegisterReceiptID
From RegisterReceipt rr join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
Right join SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID
join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
Where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and rr.OperatorID = @OperatorID
and (@Session = 0 or sp.GamingSession = @Session)
--And rr.TransactionTypeID in (1, 2, 3) -- Return all transactions not just Sale, Void, Returns
Group By rr.RegisterReceiptID, rr.TransactionNumber, tt.TransactionType, rd.VoidedRegisterReceiptID
Order by rr.TransactionNumber


--Insert the void transactions
Insert into @Results
(
RegisterReceiptID,
TransactionNumber,
TransactionType
)
Select rr.RegisterReceiptID,
	rr.TransactionNumber,
	tt.TransactionType
From RegisterReceipt rr join RegisterDetail rd on rr.OriginalReceiptID = rd.RegisterReceiptID
Right join SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID
join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
Where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and rr.OperatorID = @OperatorID
and (@Session = 0 or sp.GamingSession = @Session)
--And rr.TransactionTypeID in (1, 2, 3) -- Return all transactions not just Sale, Void, Returns
Group By rr.RegisterReceiptID, rr.TransactionNumber, tt.TransactionType, rr.OriginalReceiptID
Order by rr.TransactionNumber

Update @Results
Set TransactionType = 'Void'
Where TransactionType = 'Sale Void'

Update @Results
Set TransactionType = 'Sale * Voided'
Where VoidedRegisterReceiptID is not null

Select TransactionNumber,
	TransactionType
From @Results
Order By TransactionNumber

Set NOCOUNT OFF;
End



GO

