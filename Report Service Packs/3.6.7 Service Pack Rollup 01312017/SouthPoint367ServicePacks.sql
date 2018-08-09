use Daily
go

---- Service Pack 09.14.2017

--- Insert Report Script
-- Report Groups
-- 1 = Sales	6 = Special		11 = Tax Forms		16 = Texas
-- 2 = Paper	7 = Bingo		12 = Gaming			17 = Coupon
-- 3 = Player	8 = Electronics 13 = Inventory		18 = B3
-- 4 = Misc		9 = Exceptions	14 = Progressives
-- 5 = Staff	10 = Customer	15 = Payouts

if not exists (select * from Reports where ReportFileName = 'PlayerAttendance.rpt')
begin

    insert into Reports values (3, 1, 'PlayerAttendance.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);        -- Insert Report Parameters

    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (4, @ReturnValue);

    insert into ReportDefinitions values (5, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Player Attendace');
end;

------ Insert report
USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerAttendance]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerAttendance]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create procedure [dbo].[spRptPlayerAttendance]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the player's that attended each session
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate	as smalldatetime,
	@Session	as int
as
begin
	
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
set nocount on;

declare @Results table
(
	GamingDate		datetime,
	GamingSession	int,
	PlayerName		nvarchar(64),
	MagCardNo		nvarchar(32)
)
insert into @Results
(
	GamingDate,
	GamingSession,
	PlayerName,
	MagCardNo
)
select	rr.GamingDate,
		sp.GamingSession,
		p.FirstName + ' ' + p.LastName as PlayerName,
		pmc.MagneticCardNo
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
		join Player p on rr.PlayerID = p.PlayerID 
		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
        and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime) 
        and ( 
				@Session = 0
				or sp.GamingSession = @Session
			 ) 
        and rr.SaleSuccess = 1
        and rd.VoidedRegisterReceiptID is null
group by rr.GamingDate, 
		sp.GamingSession, 
		p.LastName, 
		p.FirstName, 
		pmc.MagneticCardNo
order by rr.GamingDate, 
		sp.GamingSession, 
		p.FirstName, 
		p.LastName;

select	*
from	@Results
order by GamingDate,
		GamingSession,
		PlayerName,
		MagCardNo;

set nocount off;

end;

GO

---- Update Bingo Revenue Summary

USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBingoRevenueSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBingoRevenueSummary]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Barry J. Silver
-- Description:	CASH BASED
--              Provide periodic summary of sales and payout info
--              This report is offered in 2 styles: Cash Based and Accrual Based.
--              Cash Based gross revenue=sales-prizes-payouts
--              Accrual based gross rev=sales-prizes-accrual increases
-- Note: sp named differently than its twin (spRptBingoRevenueSummaryAccrual) to retain biz logic in Crystal.
--
-- BJS 05/31/2011: US1851 new report
-- BJS 06/17/2011: DE8676 session number
-- bjs 06/21/2011: missing bingo sales
-- LJL 06/23/2011: Removed voided payouts from result set
-- BDH 02/22/2012: Fixed discount calculation
-- 2012.04.05 jkn: Adding support for returning data based on a fiscal date
--		not only the date range
-- TMP 01/19/2013: Removed the concession and merchandise product types.
-- jkn 03/14/2013: Changed the size of the session numbers from TINYINT to INT.  
--	This caused an issue during the NV audit when paper was issued to session 
--	number 8877 and this overflowed the session number buffer, the size was
--	then increased to and INT and all is well now.
-- TMP 07/16/2013: US2702 Changed the payout calculations to use different joins.
--  Before NULL values in Results.SessionNumber were being joined to the SessionPlayed
--  table where it did not find a match. As the SessionPlayed table grows so did the time it
--  took to run the stored procedure.
-- TMP 01/03/2014: Removed the Fiscal Date setting so that the report uses the calendar year Jan 1 to Dec 31.
--                 The fiscal date global setting is not supported.
-- TMP 01/03/2014: Changed the report to use the Session Summary table to improve the speed of the report.
--                 Requires the data to be generated in the Session Summary module in order to populate the report. 
-- 20150925(knc): Coupon sale added.
-- 2015.10.02: DE12771 Fixed issue with when there are no coupon sales no data would be returned
-- 2016.02.03 tmp: US4428/US4522 - Added the validaiton sales to Bingo Sales calculation.
-- 2016.11.08 tmp: DE13318 - Where @SessionID and/or condition was missing ().
-- 2017.09.14 tmp: DE13751 - Check if the SessionPlayedID was overridden. Fixed an issue where it could return
--                           two rows for a single session.
-- =============================================
CREATE PROCEDURE  [dbo].[spRptBingoRevenueSummary] 
(
--declare
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session    int
	
	--set @OperatorID	= 1
	--set @StartDate = '9/18/2015 00:00:00'	
	--set @EndDate	= '9/18/2015 00:00:00'	
	--set @Session    = 0

)
AS
BEGIN
    SET NOCOUNT ON;
    
SET @OperatorID = NULLIF(@OperatorID, 0);
SET @Session = NULL;--NULLIF(@Session, 0);
   
Declare @ReportStart datetime,
		@ReportEnd datetime,
		@FiscalYearStart datetime
		

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast ((datepart(year, @EndDate) - 1) as nvarchar) as datetime)

set @FiscalYearStart = dateadd(year, 1, @StartDate)


DECLARE @Results TABLE
(
	 Yr					INT
	,FiscalYearStart	SMALLDATETIME
	,MonthInt			INT
	,MonthNm			NVARCHAR(32)	
	,SessionPlayedID	INT
	,GamingDate			SMALLDATETIME	
	,SessionNumber		INT
	,Attendance			INT
	,BingoSales			MONEY
	,BingoPrizes		MONEY
	,AccrualPayouts		MONEY
	,AccrualIncreases	MONEY
);
INSERT INTO @Results
(
	SessionPlayedID,
	GamingDate,
	SessionNumber,
	Attendance,
	BingoSales,
	BingoPrizes,
	AccrualPayouts,
	AccrualIncreases
)

Select	sp.SessionPlayedID,
		sp.GamingDate,
		sp.GamingSession,
		ss.ManAttendance,
		ISNULL((SUM(ss.PaperSales) + SUM(ss.ElectronicSales) + SUM(ss.BingoOtherSales) - SUM(ss.Discounts) /*+ isnull(cpn.Coupon, 0)*/ + SUM(ss.ValidationSales)) ,   0) as BingoSales, -- US4522
		ISNULL((SUM(ss.CashPrizes) + SUM(ss.CheckPrizes) + SUM(ss.MerchandisePrizes)), 0) as BingoPrizes,
		ss.AccrualPayouts,
		ss.AccrualIncrease
From SessionSummary ss join SessionPlayed sp on ss.SessionPlayedID = sp.SessionPlayedID
  /*  left join (select Sum(NetSales) as Coupon, GamingSession
               from dbo.FindCouponSales(@OperatorID, @StartDate,@EndDate, ISNULL(@Session, 0))
			   group by GamingSession) cpn on cpn.GamingSession = sp.GamingSession */
Where sp.OperatorID = @OperatorID
    And sp.GamingDate >= @StartDate
    And sp.GamingDate <= @EndDate
    And ( sp.GamingSession = @Session	--DE13318
          or @Session is null
         )
    and	sp.IsOverridden = 0	--DE13751
Group BY sp.GamingDate, sp.SessionPlayedID, sp.GamingSession, ss.ManAttendance, ss.AccrualPayouts, ss.AccrualIncrease /*, cpn.Coupon*/

UPDATE @Results
SET  Yr = DATEPART(year, r.GamingDate)
	,FiscalYearStart = @FiscalYearStart
	,MonthInt = MONTH(r.GamingDate)
	,MonthNm = DATENAME(MONTH, r.GamingDate)
FROM @Results r

SELECT 
	 Yr
	,FiscalYearStart
	,MonthInt
	,MonthNm
	,GamingDate
	,SessionNumber
	,Attendance
	,BingoSales
	,BingoPrizes
	,AccrualPayouts
	,AccrualIncreases
FROM @Results;
    
    SET NOCOUNT OFF;
END;

GO

----- Service Pack 11.03.2017

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
go

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

--------------- Service Pack 11.17.2017

use Daily
go

declare @rptIDStaff int

select	@rptIDStaff = ReportID 
from	Reports 
where	ReportFileName = 'StaffReport.rpt';

if exists
	(
		select 1
		from	ReportDefinitions
		where	ReportID = @rptIDStaff and ReportParameterID = 53
	)
	begin
		delete from ReportDefinitions where ReportID = @rptIDStaff and ReportParameterID = 53
	end;

if not exists 
	(
		select	1
		from	ReportDefinitions 
		where	ReportID = @rptIDStaff and ReportParameterID = 64
	)
	begin
		insert into ReportDefinitions (ReportParameterID, ReportID)
		values (64, @rptIDStaff)
	end;
go

USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStaffReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStaffReport]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptStaffReport] 
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - Detail report that list each staff member that has access to the system.
--
-- 2011.10.12 bjs: US1954 report creation
-- 2011.11.10 bsb: added address and contact, using it in sprptStaffReport
-- 2011.12.09 bsb: DE9619
-- 2017.11.16 tmp: US5474 Added IsActive parameter and where condition.
-- =============================================

(
	@IsActive int
)

AS
	
begin
    
-- Temp table so Crystal can determine the shape of the output
declare @RESULTS table
(
    LastName        nvarchar(64),
    FirstName       nvarchar(64),
    address1        nvarchar(128),
    address2        nvarchar(128),
    city            nvarchar(64),
    state			nvarchar(64),
    zip				nvarchar(64),
    country         nvarchar(64),
    ContactPhone    nvarchar(16),
    StaffId         int,
    PositionId      int,
    PositionName    nvarchar(100),
    LoginNumber     int,
    IsActive        bit,
    DateCreated     datetime,
    LastLogin       datetime,
    PwdChanged      datetime,
    DisabledDate    datetime
);


insert into @RESULTS 
select 
	s.LastName
    ,s.FirstName 
	,a.Address1
	,a.Address2
	,a.City
	,a.State
	,a.Zip
	,a.Country	
	,s.HomePhone[ContactPhone]
	,s.StaffID
	, p.PositionID, p.PositionName [Position]
	, s.LoginNumber, s.IsActive
	, s.DTCreated [DateCreated]
	, s.LastLoginDate[LastLogin]
	, (
		select max(spl.DTStamp)
		from StaffPWDLog spl
		where s.StaffID = spl.StaffID
		) [PasswordChanged]
	, s.AccountLockedDate[DisabledDate]   
	from Staff s
	left join StaffPositions sp on s.StaffID = sp.StaffID
	left join Position p on sp.PositionID = p.PositionID
	left join Address a on a.AddressID = s.AddressID
	where s.StaffID > 2	
	--where s.IsActive = 1
			and s.IsActive = @IsActive

declare @staffId int;
declare @desc varchar(1024);
declare @startIndex int;
declare @endIndex int;
declare @deActId int;
declare @DTStamp DateTime;
declare audit_cursor cursor fast_forward read_only
		for select  description,DTStamp from AuditLog
		where description like '%account deactivated%'
		order by DTStamp ;
open audit_cursor
fetch next from audit_cursor into @desc,@DTStamp;

while(@@FETCH_STATUS = 0)
begin     
	if(PATINDEX('%account deactivated%',@desc)) > 0
	begin
		set @startIndex = CHARINDEX(':',@desc) + 1;
		set @endIndex = CHARINDEX(')',@desc);
	    set @deActId = convert(int,substring(@desc,@startIndex,@endIndex-@startIndex));
	   
	    update @Results
	    set DisabledDate = @DTStamp
	    where StaffId = @deActId
	    and IsActive = 0;
	end;
	
	fetch next from audit_cursor into @desc,@DTStamp;	

end
close audit_cursor;
deallocate audit_cursor;
select * 
from @RESULTS
order by LastName, StaffID, PositionName;

end;

SET NOCOUNT OFF

GO

USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerAttendance]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerAttendance]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptPlayerAttendance]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the player's that attended each session
-- 20171113 tmp: US5471 Add the player spend
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate	as smalldatetime,
	@Session	as int
as
begin
	
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
set nocount on;

declare @Results table
(
	GamingDate		datetime,
	GamingSession	int,
	PlayerName		nvarchar(64),
	MagCardNo		nvarchar(32),
	Spend			money
)
insert into @Results
(
	GamingDate,
	GamingSession,
	PlayerName,
	MagCardNo,
	Spend
)
--select	rr.GamingDate,
--		sp.GamingSession,
--		p.FirstName + ' ' + p.LastName as PlayerName,
--		pmc.MagneticCardNo
--from	RegisterReceipt rr
--		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
--		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
--		join Player p on rr.PlayerID = p.PlayerID 
--		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
--where	rr.OperatorID = @OperatorID
--		and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
--        and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime) 
--        and ( 
--				@Session = 0
--				or sp.GamingSession = @Session
--			 ) 
--        and rr.SaleSuccess = 1
--        and rd.VoidedRegisterReceiptID is null
--group by rr.GamingDate, 
--		sp.GamingSession, 
--		p.LastName, 
--		p.FirstName, 
--		pmc.MagneticCardNo
--order by rr.GamingDate, 
--		sp.GamingSession, 
--		p.FirstName, 
--		p.LastName;

select  rr.GamingDate,
		sp.GamingSession,
		p.FirstName + ' ' + p.LastName as PlayerName,
		pmc.MagneticCardNo,
		case rr.TransactionTypeID 
			when 1 then (	(sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) 
							+ (sum(isnull(rd.DiscountAmount, 0) * isnull(rd.Quantity, 0))) 
							+ (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)))
							+ (sum(isnull(rd.DeviceFee, 0)))
						)
			when 3 then (	(sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) 
							+ (sum(isnull(DiscountAmount, 0) * isnull(Quantity, 0))) 
							+ (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)))
							+ (sum(isnull(rd.DeviceFee, 0))) * -1
						)
		end 
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
		join Player p on rr.PlayerID = p.PlayerID 
		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and (	
				@Session = 0 or
				sp.GamingSession = @Session
			)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID in (1, 3)
		and rd.VoidedRegisterReceiptID is null
group by rr.GamingDate, 
		sp.GamingSession, 
		p.LastName, 
		p.FirstName, 
		pmc.MagneticCardNo,
		rr.TransactionTypeID
order by rr.GamingDate, 
		sp.GamingSession, 
		p.FirstName, 
		p.LastName;

select	GamingDate,
		GamingSession,
		PlayerName,
		MagCardNo,
		sum(Spend) as Spend
from	@Results
group by GamingDate,
		GamingSession,
		PlayerName,
		MagCardNo
order by GamingDate,
		GamingSession,
		PlayerName,
		MagCardNo;

set nocount off;

end;

GO

--------- Service Pack 01.11.2018

USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBlowerLog]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBlowerLog]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[spRptBlowerLog] 
-- =============================================
-- Author:		Travis Pollock
-- Create date: 12/30/2016
-- Description:	US4813 Retrieves the balls pulled by the blower.
-- 20170131 tmp: DE13432 - @OperatorID parameter was misspelled. 
-- =============================================
-- Add the parameters for the stored procedure here
		@OperatorID int,
		@StartDate	datetime,
		@EndDate	datetime,
		@Session	int
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;
	
	declare @Results table
	(
		GamingDate		datetime,
		GamingSession	int,
		GamePlayedId	int,
		GameNumber		int,
		PartNumber		int,
		GameName		nvarchar(64),
		SequenceNumber	int,
		DTStamp			datetime,
		BallNumber		int,
		BonanzaPreCall	bit,
		BonusPreCall	bit,
		IsIgnored		bit
	);
	
	declare @Sequential nvarchar(32);

	set @Sequential =	( select	SettingValue
						  from		GlobalSettings
						  where		GlobalSettingID = 323);
	if @Sequential = 'True'
	begin
		insert into @Results
		(
			GamingDate,
			GamingSession,
			GamePlayedId,
			GameNumber,
			PartNumber,
			GameName,
			SequenceNumber,
			DTStamp,
			BallNumber,
			BonanzaPreCall,
			BonusPreCall,
			IsIgnored
		)
		select	s.GamingDate,
				s.GamingSession,
				sp.SessionGamesPlayedID,
				sp.DisplayGameNo,
				sp.DisplayPartNo,
				sp.GameName,
				sp.GameSeqNo,
				b.DTStamp,
				b.BallNumber,
				b.IsBonanzaPreCall,
				b.IsBonusPreCall,
				b.IsIgnoredCall
		from	BlowerLog b
				left join SessionGamesPlayed sp on b.SessionGamesPlayedID = sp.SessionGamesPlayedID
				left join SessionPlayed s on sp.SessionPlayedID = s.SessionPlayedID				
			--	left join BlowerLog b on sp.SessionGamesPlayedID = b.SessionGamesPlayedID
		where	--s.OperatorID = @OperatorID 
				 CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) >= @StartDate
				and CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) <= @EndDate
				--and	s.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
				--and s.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
				and ( @Session = 0 
					  or s.GamingSession = 1
					);
	end
	else
	begin
		insert into @Results
		(
			GamingDate,
			GamingSession,
			GamePlayedId,
			GameNumber,
			PartNumber,
			GameName,
			SequenceNumber,
			DTStamp,
			BallNumber,
			BonanzaPreCall,
			BonusPreCall,
			IsIgnored
		)
		select	s.GamingDate,
				s.GamingSession,
				sp.SessionGamesPlayedID,
				sp.DisplayGameNo,
				sp.DisplayPartNo,
				sp.GameName,
				sp.GameSeqNo,
				b.DTStamp,
				b.BallNumber,
				b.IsBonanzaPreCall,
				b.IsBonusPreCall,
				b.IsIgnoredCall
		from	BlowerLog b
				left join SessionGamesPlayed sp on b.SessionGamesPlayedID = sp.SessionGamesPlayedID
				left join SessionPlayed s on sp.SessionPlayedID = s.SessionPlayedID
		--		left join BlowerLog b on sp.SessionGamesPlayedID = b.SessionGamesPlayedID
		where	--s.OperatorID = @OperatorID
				CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) >= @StartDate
				and CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) <= @EndDate
			--	and	s.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
			--	and s.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
				and ( @Session = 0 
					  or s.GamingSession = 1
					);
	end;			
			    
	select	*
	from	@Results
	order by DTStamp;

	set nocount off;

end;

GO