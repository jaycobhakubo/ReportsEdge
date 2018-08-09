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

