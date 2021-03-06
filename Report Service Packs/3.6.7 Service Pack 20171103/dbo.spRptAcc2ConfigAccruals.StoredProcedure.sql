USE [Daily]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAcc2ConfigAccruals]') AND type in (N'P', N'PC'))
DROP PROCEDURE [spRptAcc2ConfigAccruals]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [spRptAcc2ConfigAccruals] 
    @OperatorID AS int,
	@IsActive AS int = -1
	-- 2017.10.02 JBV: (DE13773) changed to use appropriate allocation tier data.
AS
BEGIN

	SET NOCOUNT ON;

	SET @IsActive = CASE WHEN @IsActive <> 0 AND @IsActive IS NOT NULL THEN 1 ELSE NULL END;
	SET @OperatorID = NULLIF(@IsActive, 0);

	SELECT a.accrualID, o.OperatorID, o.OperatorName
		, accrualName 
			= CASE 
				WHEN a.isActive = 0 THEN '(Inactive) ' 
				ELSE '' 
				END 
			+ a.accrualName
		, a.isActive
		, a.accrualTypeID, accrT.atAccrualTypeName
		, focusedAccountName = fa.accountName 
		, tieringType = CASE WHEN a.accrualAllocationTieringTypeID IS NULL THEN 'None' ELSE tt.tieringTypeName END
		, a.appliesToAllPrograms, a.appliesToAllProducts
	FROM Acc2Accrual AS a
		LEFT JOIN AccrualIncreaseType AS ait ON a.accrualIncreaseTypeID = ait.aitAccrualIncreaseTypeID
		LEFT JOIN RoundingRules AS rr ON a.preliminaryWithholdingRoundingRuleID = rr.RoundingRuleID
		LEFT JOIN Operator AS o ON a.operatorID = o.OperatorID
		LEFT JOIN AccrualType AS accrT ON a.accrualTypeID = accrT.atAccrualTypeID
		LEFT JOIN Acc2Account AS fa ON a.focusedAccountID = fa.accountID
		LEFT JOIN Acc2AccrualAllocationTieringTypes AS tt ON a.accrualAllocationTieringTypeID = tt.accrualAllocationTieringTypeID
	WHERE (@OperatorID IS NULL OR @OperatorID = a.operatorID)
		AND (@IsActive IS NULL OR (@IsActive = 0 AND a.isActive = 0) OR (@IsActive = 1 AND a.isActive = 1))
	ORDER BY a.isActive DESC, a.accrualName
	;

	SET NOCOUNT OFF;

END
GO
