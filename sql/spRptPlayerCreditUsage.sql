
USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCreditUsageReport]    Script Date: 05/08/2012 16:43:16 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCreditUsageReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCreditUsageReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCreditUsageReport]    Script Date: 05/08/2012 16:43:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[spRptCreditUsageReport]
@OperatorID int,
@PlayerID INT,
@StartDate DATETIME, 
@EndDate DATETIME 
AS
SET NOCOUNT ON
/** gtdVoidDate was used on report but not in the procedure, added it back to select statement***/
select gtTransDate, 
gtTransTotal, gtdDelta, gtdVoidDate, gtdPrevious, gtdPost,
	gtRegisterreceiptID,
	LastVisitDate,
	--PointsBalance = pbPointsBalance,
	tcTransCategory, LastName, MiddleInitial, FirstName, P.PlayerID,
	TransactionType,  tcTransCategoryDesc, Refundable, NonRefundable, CashOnly,PIn.OperatorID 
from History.dbo.GameTrans (nolock)
Join Player P (nolock) on gtPlayerID = P.PlayerID
Join PlayerInformation PIn (nolock) on P.PlayerID = PIn.PlayerID
Join CreditBalances CB (nolock) on gtCreditbalancesID = CB.CreditBalancesID
--Join PointBalances (nolock) on gtPointBalancesID = pbPointBalancesID
Join History.dbo.GameTransDetail (nolock) on gtGameTransID = gtdGameTransID
Join TransCategory (nolock) on gtdTransCatID = tcTransCatID
Left Join TransactionType TT (nolock) on gtTransactionTypeID = TransactionTypeID
Where Cast(Convert(varchar(24), gtTransDate,101) as smalldatetime) >= Cast(Convert(varchar(24), @StartDate,101) as smalldatetime)
and Cast(Convert(varchar(24), gtTransDate,101) as smalldatetime) <= Cast(Convert(varchar(24), @EndDate, 101) as smalldatetime)
and (@PlayerID = 0 or gtPlayerID = @PlayerID)
and (PIn.OperatorID = @OperatorID or @OperatorID = 0)
and gtdTransCatID <> 3

SET NOCOUNT OFF




GO


