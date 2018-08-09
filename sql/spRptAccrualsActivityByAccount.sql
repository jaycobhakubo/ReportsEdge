USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptAccrualsActivityByAccount]    Script Date: 10/07/2013 17:55:58 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAccrualsActivityByAccount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptAccrualsActivityByAccount]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptAccrualsActivityByAccount]    Script Date: 10/07/2013 17:55:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- ===============================================
-- Author:		Tygh Porak
-- Create date: 04/27/2011
-- Description:	Accrual Activity By Account Report
-- 2011.07.05 bjs: DE8860 sort by transaction date
-- ===============================================
CREATE PROCEDURE [dbo].[spRptAccrualsActivityByAccount] 
	@OperatorID as int,
	@AccrualName AS NVARCHAR(40) = NULL,
	@StartDate AS DATETIME, 
	@EndDate AS DATETIME,
	@Session as int
	
AS
BEGIN

-- =============================================
-- Execution Test Case - Tygh Porak
/* =============================================
   DECLARE
   @startTime			DATETIME
   
   SET @startTime = GETUTCDATE();
   
   EXECUTE [dbo].[spRptAccrualsActivityByAccount]
		@OperatorID     = 0
		,@AccrualName	= '%'						-- Pass wild carded string
        ,@Session       = 0
		,@StartDate		= '01/01/2011 00:00:00'		-- 
		,@EndDate		= '06/01/2011 00:00:00'		--
		
   PRINT 'Execution Time : '
		+ CAST(DATEDIFF(ms, @startTime, GETUTCDATE()) AS NVARCHAR(20))
				+ ' milliseconds'
-- ===========================================*/

	SET NOCOUNT ON;

	SELECT      ISNULL (atd.OverrideValue, atd.Value) AS AccrualEffect, 
				atd.PreviousBalance,
				atd.PostBalance,
				aa.aaSequence,
				a.aOperatorID,
				CASE WHEN at.TransactionTypeID = 37 OR at.TransactionTypeID = 5 
					THEN atd.AccountIncreasePercentage 
					ELSE -1 END [AccountIncreasePercentage], 
				at.DTStamp,
				at.GamingDate,
				sp.GamingSession,
				s.LoginNumber,
				tt.TransactionType,
				a.aAccrualName,
				at.StaffId,
				s.LastName, s.FirstName, s.StaffId
				,ISNULL (at.Notes, '') as Notes
				
	FROM        AccrualTransactionDetails AS atd 
				INNER JOIN AccrualAccount AS aa ON atd.AccrualAccountID = aa.aaAccrualAccountID 
				INNER JOIN AccrualTransactions AS at ON atd.AccrualTransactionID = at.AccrualTransactionID 
				INNER JOIN TransactionType AS tt ON at.TransactionTypeID = tt.TransactionTypeID 
				INNER JOIN Accrual AS a ON aa.aaAccrualID = a.aAccrualID AND at.AccrualID = a.aAccrualID 
                INNER JOIN AccrualType AS atype ON a.aAccrualTypeID = atype.atAccrualTypeID
				left join Staff AS s ON at.StaffID = s.StaffID 
                left join SessionPlayed sp on at.SessionPlayedId = sp.SessionPlayedId
    WHERE  a.aAccrualName LIKE @AccrualName
		   AND (at.GamingDate BETWEEN @StartDate AND @EndDate)
		   and (@OperatorID = 0 or a.aOperatorID = @OperatorID)
		   and (@Session = 0 OR sp.GamingSession = @Session)
    ORDER BY a.aAccrualName, aa.aaSequence, at.DTStamp, sp.GamingSession;
END







GO

