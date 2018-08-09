USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionAccrualIncrease]    Script Date: 02/22/2012 08:16:23 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionAccrualIncrease]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionAccrualIncrease]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionAccrualIncrease]    Script Date: 02/22/2012 08:16:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptSessionAccrualIncrease] 
(
    @OperatorID INT,
    @GamingDate DATETIME,
    @Session INT,
    @IncludeConcessions INT,
    @IncludeMerchandise INT,
    @IncludePullTabs INT
)    
AS
BEGIN

SET NOCOUNT ON

	
	select at.AccrualName, atd.Value as AccrualIncrease
	from AccrualTransactionDetails atd
		JOIN AccrualTransactions at ON (atd.AccrualTransactionID = at.AccrualTransactionID)
		join Accrual a on at.AccrualID = a.aAccrualID
		join SessionPlayed s on at.SessionPlayedId = s.SessionPlayedID
	where	s.GamingSession = @Session 
		and	at.TransactionTypeID IN (5, 37)
		and at.GamingDate = @GamingDate
		and a.aOperatorID = @OperatorID
	
			


set nocount off

end
GO


