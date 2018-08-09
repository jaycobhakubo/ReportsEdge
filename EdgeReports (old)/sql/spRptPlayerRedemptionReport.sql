USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerRedemptionReport]    Script Date: 01/31/2012 13:57:33 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerRedemptionReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerRedemptionReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerRedemptionReport]    Script Date: 01/31/2012 13:57:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[spRptPlayerRedemptionReport]
(
-- =============================================
-- Author:		Barjinder Bal
-- Description:	Redemption Report
--
-- 01/31/12 bsb: DE9974 added void receipts
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,	
	@Session	AS	INT,
	@PlayerID   As  INT
)	
as
	
	
BEGIN

set nocount on;

-- Verfify POS sending valid values

set @Session = isnull(@Session, 0);
set @PlayerID = isnull(@PlayerID, 0);



-- Results table	
declare @Results table
	(
	    TransactionDate			datetime,
	    SessionNo				int,	
	    StaffLastName			varchar(64),
	    StaffFirstName			varchar(64),
	    ReceiptNumber			int,
	    PlayerID				int,
	    PlayerLastName			varchar(64),
	    PlayerFirstName			varchar(64),
	    Quantity				int,
	    ProductName				varchar(100),
	    DollarValue				money,
	    PointsAmount			int
	);

insert into @Results
select rr.GamingDate,isnull(sp.GamingSession,0), s.LastName,s.FirstName,rr.TransactionNumber,
       p.PlayerID,p.LastName,p.FirstName,rd.Quantity,rd.PackageName,  
       abs(rd.Quantity * rd.PackagePrice),   rd.TotalPtsRedeemed  *(-1)   
from Player p
	join RegisterReceipt rr on p.PlayerID = rr.PlayerID
	join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID 
	left join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
	join Staff s on rr.StaffID = s.StaffID
	left join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
where rd.TotalPtsRedeemed > 0
	and  rr.GamingDate >= @StartDate
	and  rr.GamingDate <= @EndDate
	and (@PlayerID = 0 or p.PlayerID = @PlayerID)
	and (@Session = 0 or sp.GamingSession = @Session)
	and (@OperatorID = 0 or rr.OperatorID = @OperatorID)
--	and rd.VoidedRegisterReceiptID is null
order by rr.GamingDate

--voided receipts
insert into @Results
select rr.GamingDate,isnull(sp.GamingSession,0), s.LastName,s.FirstName,rr2.TransactionNumber,
       p.PlayerID,p.LastName,p.FirstName,rd.Quantity,rd.PackageName,  
       (abs(rd.Quantity * rd.PackagePrice ))*(-1),   rd.TotalPtsRedeemed  *(1)   
from Player p
	join RegisterReceipt rr on p.PlayerID = rr.PlayerID
	join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID 
	left join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
	join Staff s on rr.StaffID = s.StaffID
	left join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID

 inner join 
 RegisterReceipt rr2
 on rr.RegisterReceiptID = rr2.OriginalReceiptID
where rd.TotalPtsRedeemed > 0
and rr2.TransactionTypeID = 2
	and  rr2.GamingDate >= @StartDate
	and  rr2.GamingDate <= @EndDate
	and (@PlayerID = 0 or p.PlayerID = @PlayerID)
	and (@Session = 0 or sp.GamingSession = @Session)
    and (@OperatorID = 0 or rr.OperatorID = @OperatorID)
select * from @Results order by ReceiptNumber;

END









GO


