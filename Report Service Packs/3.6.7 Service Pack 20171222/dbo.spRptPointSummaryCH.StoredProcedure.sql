USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPointSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPointSummary]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

----------------------------
--kc|US2262|7/18/2012|New Report
-- 2014.04.03 tmp: DE11700 Report the points earned and redeemed for all operators. 
-- 2015.09.18 tmp: DE12750 Void transactions increment the Points Earned and Points Redeemed.
-- 2016.06.02 tmp: US4706  Added support for points earned from qualifying spend. 
-- 2016.06.14 tmp: DE13014 Points Earned and Points Redeemed were off if there were returns and void of returns.
-- 2017.02.23 RAK: Included points per dollar from discounts in earned points and keep earned points from going negative (DE13475).
-- 2017.12.22 tmp: Complete re-write for Cher Heights
----------------------------------

CREATE proc [dbo].[spRptPointSummary]
--declare 
@OperatorID int,
@StartDate datetime,
@EndDate datetime

--set @OperatorID = 1
--set @StartDate = '8/13/2012 00:00:00'
--set @EndDate = '8/13/2012 00:00:00'

--exec spRptPointSummary 1,'11/7/2017','11/7/2017'

as
begin

declare @CurrentDate datetime
set @CurrentDate = CAST(CONVERT(varchar(12), getdate(), 101) AS smalldatetime)

declare @PointValue money
set		@PointValue = .02

--exec spRptPointSummary 1,'8/13/2012 00:00:00','8/13/2012 00:00:00'
declare @FinalResults table
(
	GamingDate			datetime
	, PointsEarned		money
	, PointsRedeemed	money
	, PointDifference	money
	, CurrentBalance	money
	, PointValue		money
)

--- Get missing transactions to find the overstated/understated point balance
	declare @OverUnderPoints money

	declare @PreSale table
	(
		RegRec	int,
		PlayerID int,
		PreSale money
	)
	;with cte as
	(
		select	*,
				row_number() over(partition by PlayerID order by RegisterReceiptID asc) as rn
		from	RegisterReceipt
	)
	insert into @PreSale
	select 
			RegisterReceiptID,
			PlayerID,
			PreSalePoints
	from cte
	where rn = 1
			and PlayerID is not null
	order by PlayerID;

	declare @OUResults table
	(
		PlayerID int,
		BegBalance money,
		Change	money,
		EndBalance money,
		pbBalance money
	)
	;with cte as
	(
		select	*,
				row_number() over(partition by gtPlayerID order by gtGameTransID asc) as rn
		from	history.dbo.GameTrans
	)
	insert into @OUResults
	(
		PlayerID,
		BegBalance
	)
	select	c.gtPlayerID,
			gtd.gtdPrevious
	from cte c join history.dbo.GameTransDetail gtd on c.gtGameTransID = gtd.gtdGameTransID
	where rn = 1
	order by gtPlayerID;

	;with cteEnd as
	(
		select	*,
				row_number() over(partition by gtPlayerID order by gtGameTransID desc) as rn
		from	history.dbo.GameTrans
	)
	insert into @OUResults
	(
		PlayerID,
		EndBalance
	)
	select	ce.gtPlayerID,
			gtd.gtdPost
	from cteEnd ce join history.dbo.GameTransDetail gtd on ce.gtGameTransID = gtd.gtdGameTransID
	where rn = 1
	order by gtPlayerID;

	insert into @OUResults
	(
		PlayerID,
		pbBalance
	)
	select  pin.PlayerID,
			pb.pbPointsBalance
	from	PointBalances pb
			join PlayerInformation pin on pb.pbPointBalancesID = pin.PointBalancesID;
			
	declare @RRPoints table
	(
		rrPlayerID int
		, rrEarned money
		, rrRedeemed money
		, rrDelta money
	)
	insert into @RRPoints
	(
		rrPlayerID
		, rrEarned
	)
		select  rr.PlayerID
				, sum(Quantity * DiscountAmount * DiscountPtsPerDollar)
		from	RegisterDetail rd
				join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		where	DiscountTypeID is not null
				and rr.TransactionTypeID = 1
				and rd.VoidedRegisterReceiptID is null
				and rr.SaleSuccess = 1
				and rr.PlayerID is not null
	group by rr.PlayerID;
				
	insert into @RRPoints
	(
		rrPlayerID
		, rrEarned
	)

	select  rr.PlayerID
			,sum(Quantity * isnull(rd.TotalPtsEarned, 0)) as PointsEarned
	from	RegisterDetail rd
			join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
	where	DiscountTypeID is null
			and rr.TransactionTypeID = 1
			and rd.VoidedRegisterReceiptID is null
			and rr.SaleSuccess = 1
			and rr.PlayerID is not null
	group by rr.PlayerID;

	insert into @RRPoints
	(
		rrPlayerID
		, rrRedeemed
	)

	select  rr.PlayerID
			,sum(Quantity * isnull(rd.TotalPtsRedeemed, 0)) as PointsEarned
	from	RegisterDetail rd
			join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
	where	DiscountTypeID is null
			and rr.TransactionTypeID = 1
			and rd.VoidedRegisterReceiptID is null
			and rr.SaleSuccess = 1
			and rr.PlayerID is not null
	group by rr.PlayerID;

	;with CompareTable
	(
		ctPlayerID,
		ctDelta
	)
	as
	(
	select	rrPlayerID	
			, sum(rrEarned) - sum(rrRedeemed) 
	from @RRPoints
	group by rrPlayerID
	)
	insert @OUResults
	(
		PlayerID,
		Change
	)
	select ctPlayerID,
			ctDelta
	from CompareTable
		
	;with cte2 
	(
		PlayerID,
		BB,
		BC,
		CalcEnd,
		PostEnd,
		PBEnd
	)
	as
	(		
	select	r.PlayerID,
			sum(BegBalance),
			sum(Change),
			sum(BegBalance) + sum(Change),
			sum(EndBalance),
			sum(pbBalance)
	from	@OUResults r
	group by r.PlayerID
	)
	select  @OverUnderPoints = sum((ps.PreSale + c2.BC ) - c2.PBEnd)
	from cte2 c2 
		join @OUResults r on c2.PlayerID = r.PlayerID
		join @PreSale ps on r.PlayerID = ps.PlayerID
	where c2.CalcEnd <> r.pbBalance;

declare @Results table
(
	GamingDate			datetime
	, PointsEarned		money
	, PointsRedeemed	money
	, PointDifference	money
	, CurrentBalance	money
	, PointChange		money
)

insert into @Results
(
	GamingDate,
	PointsEarned
)
select  rr.GamingDate,
		sum(Quantity * DiscountAmount * DiscountPtsPerDollar)
from	RegisterDetail rd
		join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
where	DiscountTypeID is not null
		and rr.TransactionTypeID = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.SaleSuccess = 1
		and rr.PlayerID is not null
group by rr.GamingDate;
		
insert into @Results
(
	GamingDate,
	PointsEarned
)		
select  rr.GamingDate,
		sum(Quantity * isnull(rd.TotalPtsEarned, 0))
from	RegisterDetail rd
		join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
where	DiscountTypeID is null
		and rr.TransactionTypeID = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.SaleSuccess = 1
		and rr.PlayerID is not null
group by GamingDate;

insert into @Results
(
	GamingDate,
	PointsRedeemed
)		
select  rr.GamingDate,
		sum(Quantity * rd.TotalPtsRedeemed) as PointsRedeemed
from	RegisterDetail rd
		join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
where	DiscountTypeID is null
		and rr.TransactionTypeID = 1
		and rd.VoidedRegisterReceiptID is null
		and rr.SaleSuccess = 1
		and rr.PlayerID is not null
group by GamingDate;

-- US4706 start Insert points earned from qualifying spend. 
insert into @Results
(
	GamingDate,
	PointsEarned
)
select	rr.GamingDate
		, sum(isnull(PointsFromQualifyingAmount, 0))
from	RegisterReceipt rr
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= CAST(CONVERT(VARCHAR(24), @StartDate, 101) AS SmallDateTime)
		and rr.GamingDate <= CAST(CONVERT(VARCHAR(24), @CurrentDate, 101) AS SmallDateTime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID in (1, 3, 10, 12)	
		and rr.PlayerID is not null 
		and not exists ( select OriginalReceiptID
						 from	RegisterReceipt rr2
					     where	rr.RegisterReceiptID = rr2.OriginalReceiptID)
group by rr.GamingDate
-- US4706 End

insert @FinalResults
(
	GamingDate,
	PointsEarned,
	PointsRedeemed,
	PointDifference
)
select	isnull(r.GamingDate, @CurrentDate),
		isnull(sum(PointsEarned), 0),
		isnull(sum(PointsRedeemed), 0),
		isnull(sum(PointsEarned) - sum(PointsRedeemed), 0)
from	@Results r 
group by GamingDate
order by GamingDate

update @FinalResults
set CurrentBalance = (
						select	sum(pbPointsBalance) + isnull(@OverUnderPoints, 0)
						from	PointBalances
					)
	, PointValue = @PointValue
					
select	r.*
		, PointChange = (	
							select	sum(PointDifference)
							from	@FinalResults r2 
							where	r2.GamingDate >= r.GamingDate
						)
from	@FinalResults r 
where	r.GamingDate >= @StartDate
		and r.GamingDate <= @EndDate
order by GamingDate;

end

GO

