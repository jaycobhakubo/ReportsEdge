USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCardLevelDistribution]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCardLevelDistribution]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure  [dbo].[spRptCardLevelDistribution]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: Number of cards sold by level. Number of winners by level.
 -- Notes:
 -- Supports 12on Rainbow Paper, does not support other paper Rainbow On.  
 -- Rainbow Paper is broken down to 4 Blue, 4 Red, 4 Green. 
 --		Rainbow paper can be changed under Insert into @SmRainbow.
 -- Card Level names are hardcoded to look for like 'blue', 'red', 'green', 'tan'.
 -- Game Category name is hardcoded to look for like 'regular'.
 --=============================================    
  
	@OperatorID	as int,    
	@StartDate  as datetime,    
	@EndDate	as datetime,
	@Session	as int    
as   

-->>>>>>>>>>>>>>>>>>TEST START<<<<<<<<<<<<<<<<<<  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime
  
--set @OperatorID = 1   
--set @StartDate = '03/18/2014 00:00:00'  
--set @EndDate = '03/18/2014 00:00:00'  
--TEST END  
-->>>>>>>>>>>>>>>>>>>>TEST END<<<<<<<<<<<<<<<<<<<<<
     
set nocount on    

declare @Results table
(
	GamingSession	int
	, LvlName		nvarchar(32)
	, LvlMultiplier	int
	, CardCount		int
	, WinCount		int
)
insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, CardCount
)
select	sp.GamingSession
		, rdi.CardLvlName
		, cl.Multiplier
		, sum(rdi.Qty * rdi.CardCount * rd.Quantity) as ElectronicCards
from	RegisterReceipt rr with (nolock)
		join RegisterDetail rd with (nolock) on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi with (nolock) on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp with (nolock) on rd.SessionPlayedID = sp.SessionPlayedID
		join CardLevel cl with (nolock) on rdi.CardLvlID = cl.CardLevelID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= @StartDate
		and rr.GamingDate <= @EndDate
		and (
				@Session = 0
				or sp.GamingSession = @Session
			)
		and ( 
				rdi.CardLvlName like '%blue%'
				or rdi.CardLvlName like '%red%'
				or rdi.CardLvlName like '%green%'
				or rdi.CardLvlName like '%tan%'
			)
		and rdi.GameCategoryName like '%regular%'
		and rdi.CardMediaID = 1
		and rd.VoidedRegisterReceiptID is null
group by sp.GamingSession 
	, rdi.CardLvlName
	, cl.Multiplier;
	
insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, CardCount
)		
select	sp.GamingSession
		, rdi.CardLvlName
		, cl.Multiplier
		, sum(cc.ccOn) as PaperCards
from	InvPaperTrackingPackStatus ip with (nolock)
		join RegisterDetailItems rdi with (nolock) on ip.RegisterDetailItemId = rdi.RegisterDetailItemID
		join RegisterDetail rd with (nolock) on rdi.RegisterDetailID = rd.RegisterDetailID
		join RegisterReceipt rr with (nolock) on rd.RegisterReceiptID = rr.RegisterReceiptID
		join SessionPlayed sp with (nolock) on rd.SessionPlayedID = sp.SessionPlayedID
		join InventoryItem ii with (nolock) on ip.InventoryItemId = ii.iiInventoryItemID
		join CardCuts cc with (nolock) on ii.iiCardCutID = cc.ccCardCutID
		join CardLevel cl with (nolock) on rdi.CardLvlID = cl.CardLevelID
where	rr.OperatorID = 1
		and rr.GamingDate >= @StartDate
		and rr.GamingDate <= @EndDate
		and (
				@Session = 0
				or sp.GamingSession = @Session
			)
		and ( 
				rdi.CardLvlName like '%blue%'
				or rdi.CardLvlName like '%red%'
				or rdi.CardLvlName like '%green%'
				or rdi.CardLvlName like '%tan%'
			)
		and rd.VoidedRegisterReceiptID is null
		and rdi.GameCategoryName like '%regular%'
		and rdi.ProductItemName not like '%rainbow%'
group by sp.GamingSession
	, rdi.CardLvlName
	, cl.Multiplier;
		
declare @SmRainbow table
(
	GamingSession	int
	, BlueCount		int
	, RedCount		int
	, GreenCount	int
)
insert into @SmRainbow
(
	GamingSession
	, BlueCount
	, RedCount
	, GreenCount
)	
select	sp.GamingSession
		, count(ip.AuditNumber) * 4
		, count(ip.AuditNumber) * 4	
		, count(ip.AuditNumber) * 4
from	InvPaperTrackingPackStatus ip with (nolock)
		join RegisterDetailItems rdi with (nolock) on ip.RegisterDetailItemId = rdi.RegisterDetailItemID
		join RegisterDetail rd with (nolock) on rdi.RegisterDetailID = rd.RegisterDetailID
		join RegisterReceipt rr with (nolock) on rd.RegisterReceiptID = rr.RegisterReceiptID
		join SessionPlayed sp with (nolock) on rd.SessionPlayedID = sp.SessionPlayedID
		join InventoryItem ii with (nolock) on ip.InventoryItemId = ii.iiInventoryItemID
		join CardCuts cc with (nolock) on ii.iiCardCutID = cc.ccCardCutID
where	rr.OperatorID = 1
		and rr.GamingDate >= @StartDate
		and rr.GamingDate <= @EndDate
		and (
				@Session = 0
				or sp.GamingSession = @Session
			)
		and ( 
				rdi.CardLvlName like '%blue%'
				or rdi.CardLvlName like '%red%'
				or rdi.CardLvlName like '%green%'
				or rdi.CardLvlName like '%tan%'
			)
		and rd.VoidedRegisterReceiptID is null
		and rdi.GameCategoryName like '%regular%'
		and rdi.ProductItemName like '%rainbow%'
		and cc.ccOn = 12
group by sp.GamingSession;
		
insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, CardCount
)
select  GamingSession
		, 'Blue'
		, 1.0
		, sr.BlueCount
from	@SmRainbow sr;

insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, CardCount
)
select	GamingSession
		, 'Red'
		, 2.0
		, sr.RedCount
from	@SmRainbow sr;

insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, CardCount
)
select	GamingSession
		, 'Green'
		, 3.0
		, sr.GreenCount
from	@SmRainbow sr;

-- Get the payouts by level
insert into @Results
(
	GamingSession
	, LvlName
	, LvlMultiplier
	, WinCount
)
select	sp.GamingSession
		, ptb.CardLevelName
		, ptb.CardLevelMultiplier
		, count(ptb.PayoutTransID) as WinningCount
from	PayoutTransBingoGame ptb
		join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
		join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId
		join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
where	sp.OperatorID = @OperatorID
		and sp.GamingDate >= @StartDate
		and sp.GamingDate <= @EndDate
		and (
				@Session = 0
				or sp.GamingSession = @Session
			)
		and sgc.GameCategoryName like '%regular%'
		and ( 
				ptb.CardLevelName like '%blue%'
				or ptb.CardLevelName like '%red%'
				or ptb.CardLevelName like '%green%'
				or ptb.CardLevelName like '%tan%'
			)
group by sp.GamingSession
	, ptb.CardLevelName
	, ptb.CardLevelMultiplier;

select	GamingSession
		, LvlName
		, LvlMultiplier
		, sum(CardCount) as CardCount
		, sum(WinCount) as WinCount
from	@Results
group by GamingSession 
	, LvlName
	, LvlMultiplier;

set nocount off
    


GO

