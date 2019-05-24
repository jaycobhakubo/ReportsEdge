USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindStationsAccrualBackups]    Script Date: 04/10/2019 15:52:07 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindStationsAccrualBackups]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindStationsAccrualBackups]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindStationsAccrualBackups]    Script Date: 04/10/2019 15:52:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		FortuNet
-- Create date: 4/10/2019
-- Description:	Finds the total accrued for backup accounts.
--				This amount is not included in their progressive increase towards payouts
--				for the session. 
-- Returns: GamingDate, GamingSession, Total Accrued
-- =============================================
CREATE FUNCTION [dbo].[FindStationsAccrualBackups] 
(
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME,
	@Session		AS INT
)
RETURNS 
@IncreaseResults TABLE 
(

	GamingDate DateTime,
	GamingSession int,
	IncreaseAmount money
)

AS
BEGIN

	insert into @IncreaseResults
	(
			GamingDate,
			GamingSession,
			IncreaseAmount
	)
	select	at.GamingDate
			, sp.GamingSession
			, sum(isnull(atd.actualBalanceChange, 0))
	from	Acc2Transactions at join Acc2TransactionAccountDetails atd on at.acc2TransactionID = atd.acc2TransactionID
			join Acc2Account a on atd.accountID = a.accountID
			join TransactionType t on at.transactionTypeID = t.TransactionTypeID
			left join SessionPlayed sp on at.SessionPlayedID = sp.SessionPlayedID
	where	at.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
			and at.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
			and a.operatorID = @OperatorID
			and at.transactionTypeID in (5, 37) -- Automatic progressive increases (5), manual progressive increases (37)
			and at.voidedByTransID is null
			and a.accountName like '%BU'
			and (@Session = 0 or sp.GamingSession = @Session)
	group by at.GamingDate, sp.GamingSession;

	-- This statement will return the table variable to the caller
	RETURN 
END




























GO

