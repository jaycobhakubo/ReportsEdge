USE [Daily]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAcc2ConfigAccrualsAllocations]') AND type in (N'P', N'PC'))
DROP PROCEDURE [spRptAcc2ConfigAccrualsAllocations]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [spRptAcc2ConfigAccrualsAllocations] 
    @accrualID INT
	-- 2017.10.02 JBV: (DE13773) changed to use appropriate allocation tier data.
AS
BEGIN

	SET NOCOUNT ON;

	SELECT tier.accrualAllocationTierID
		, tier.tierBeginsAt, tier.tierEndsAt
		, tierActiveRangeStr 
			= CASE 
				WHEN accr.accrualAllocationTieringTypeID IS NULL OR (tier.tierBeginsAt IS NULL AND tier.tierEndsAt IS NULL) THEN 'Always'
				WHEN accr.accrualAllocationTieringTypeID = 1 
				THEN 
					CASE 
					WHEN tier.tierBeginsAt IS NULL THEN CAST(CAST(tier.tierEndsAt AS INT) AS nvarchar) + ' or less days since focused account last paid.'
					WHEN tier.tierEndsAt IS NULL THEN CAST(CAST(tier.tierBeginsAt AS INT) AS nvarchar) + ' or more days since focused account last paid.'
					ELSE CAST(tier.tierBeginsAt AS nvarchar) + ' to ' + CAST(tier.tierEndsAt AS nvarchar) + ' days since focused account last paid.'
					END
				WHEN accr.accrualAllocationTieringTypeID = 2 
				THEN 
					CASE 
					WHEN tier.tierBeginsAt IS NULL THEN 'Focused account balance at $' + CAST(tier.tierEndsAt AS nvarchar) + ' or less.'
					WHEN tier.tierEndsAt IS NULL THEN 'Focused account balance at $' + CAST(tier.tierBeginsAt AS nvarchar) + ' or more.'
					ELSE 'Focused account balance between $' + CAST(tier.tierBeginsAt AS nvarchar) + ' and $' + CAST(tier.tierEndsAt AS nvarchar)
					END
				ELSE CAST(tier.tierBeginsAt AS nvarchar) + ' to ' + CAST(tier.tierEndsAt AS nvarchar)
			END
		, ait.aitAccrualIncreaseType, ait.aitIsPercentage
		, tier.preliminaryWithholdingAmount, tier.preliminaryWithholdingPercent
		, prelimRR.RoundingRuleName AS preliminaryWithholdingRoundingRule, tier.preliminaryWithholdingRoundingPrecision
		, allocation.sequenceInAccrual AS allocationSeq
		, CASE
				WHEN acct.isActive = 0 THEN '(Inactive) ' 
				ELSE '' 
				END 
			+ acct.accountName AS allocationAccountName
		, allocation.increaseAmount AS allocationAmount
		, allocationRR.RoundingRuleName AS allocationRoundingRule
		, allocation.roundingPrecision AS allocationRoundingPrecision
	FROM Acc2Accrual AS accr
		LEFT JOIN Acc2AccrualAllocationTiers AS tier ON accr.accrualID = tier.accrualID
		LEFT JOIN RoundingRules AS prelimRR ON tier.preliminaryWithholdingRoundingRuleID = prelimRR.RoundingRuleID
		LEFT JOIN AccrualIncreaseType AS ait ON tier.accrualIncreaseTypeID = ait.aitAccrualIncreaseTypeID
		LEFT JOIN Acc2AccrualAccounts AS allocation ON tier.accrualAllocationTierID = allocation.accrualAllocationTierID
		LEFT JOIN Acc2Account AS acct ON allocation.accountID = acct.accountID
		LEFT JOIN RoundingRules AS allocationRR ON allocation.roundingRuleID = allocationRR.RoundingRuleID
	WHERE accr.accrualID = @accrualID AND tier.isActive = 1
	ORDER BY ISNULL(tier.tierBeginsAt,-1000), ISNULL(tier.tierEndsAt, 99999), allocation.sequenceInAccrual
	;
	
	SET NOCOUNT OFF;

END
GO
