USE [Daily]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAcc2ConfigAccrualAllocationTiers]') AND type in (N'P', N'PC'))
DROP PROCEDURE [spRptAcc2ConfigAccrualAllocationTiers]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [spRptAcc2ConfigAccrualAllocationTiers] 
    @OperatorID AS int,
	@IsActive AS int = -1
	-- 2017.10.02 JBV: (DE13773) Created to support using appropriate allocation tier data on Acc2ConfigurationReport;
	--                           replacing the report's use of the spRptAcc2ConfigAccruals procedure.
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
		, aat.accrualIncreaseTypeID, ait.aitAccrualIncreaseType, ait.aitIsPercentage
		, aat.preliminaryWithholdingAmount, aat.preliminaryWithholdingPercent
		, rr.RoundingRuleName AS preliminaryWithholdingRoundingRule, aat.preliminaryWithholdingRoundingPrecision
		, a.appliesToAllPrograms, a.appliesToAllProducts
		, aat.accrualAllocationTierID
		, focusedAccountName = CASE WHEN a.focusedAccountID IS NULL THEN 'None' ELSE fa.accountName END
		, tieringType = CASE WHEN a.accrualAllocationTieringTypeID IS NULL THEN 'None' ELSE tt.tieringTypeName END
		, aat.tierBeginsAt, aat.tierEndsAt
		, tierActiveRangeStr 
			= CASE 
				WHEN a.accrualAllocationTieringTypeID IS NULL OR (aat.tierBeginsAt IS NULL AND aat.tierEndsAt IS NULL) THEN 'Always'
				WHEN a.accrualAllocationTieringTypeID = 1 
				THEN 
					CASE 
					WHEN aat.tierBeginsAt IS NULL THEN CAST(CAST(aat.tierEndsAt AS INT) AS nvarchar) + ' or less days since focused account last paid.'
					WHEN aat.tierEndsAt IS NULL THEN CAST(CAST(aat.tierBeginsAt AS INT) AS nvarchar) + ' or more days since focused account last paid.'
					ELSE CAST(aat.tierBeginsAt AS nvarchar) + ' to ' + CAST(aat.tierEndsAt AS nvarchar) + ' days since focused account last paid.'
					END
				WHEN a.accrualAllocationTieringTypeID = 2 
				THEN 
					CASE 
					WHEN aat.tierBeginsAt IS NULL THEN 'Focused account balance at $' + CAST(aat.tierEndsAt AS nvarchar) + ' or less.'
					WHEN aat.tierEndsAt IS NULL THEN 'Focused account balance at $' + CAST(aat.tierBeginsAt AS nvarchar) + ' or more.'
					ELSE 'Focused account balance between $' + CAST(aat.tierBeginsAt AS nvarchar) + ' and $' + CAST(aat.tierEndsAt AS nvarchar)
					END
				ELSE CAST(aat.tierBeginsAt AS nvarchar) + ' to ' + CAST(aat.tierEndsAt AS nvarchar)
			END
	FROM Acc2Accrual AS a
		LEFT JOIN AccrualType AS accrT ON a.accrualTypeID = accrT.atAccrualTypeID
		LEFT JOIN Operator AS o ON a.operatorID = o.OperatorID
		LEFT JOIN Acc2Account AS fa ON a.focusedAccountID = fa.accountID
		LEFT JOIN Acc2AccrualAllocationTieringTypes AS tt ON a.accrualAllocationTieringTypeID = tt.accrualAllocationTieringTypeID
		LEFT JOIN Acc2AccrualAllocationTiers AS aat ON a.accrualID = aat.accrualID AND aat.isActive = 1
		LEFT JOIN AccrualIncreaseType AS ait ON aat.accrualIncreaseTypeID = ait.aitAccrualIncreaseTypeID
		LEFT JOIN RoundingRules AS rr ON aat.preliminaryWithholdingRoundingRuleID = rr.RoundingRuleID
	WHERE (@OperatorID IS NULL OR @OperatorID = a.operatorID)
		AND (@IsActive IS NULL OR (@IsActive = 0 AND a.isActive = 0) OR (@IsActive = 1 AND a.isActive = 1))
	ORDER BY a.isActive DESC, a.accrualName
	;

	SET NOCOUNT OFF;

END
