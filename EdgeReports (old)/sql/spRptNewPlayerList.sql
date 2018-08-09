USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptNewPlayerList]    Script Date: 07/12/2012 11:21:51 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptNewPlayerList]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptNewPlayerList]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptNewPlayerList]    Script Date: 07/12/2012 11:21:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






-------------------------------
---------------------------------
--Karlo Camacho
--4/12/2012
------------------------------
---------------------------------

CREATE proc [dbo].[spRptNewPlayerList]
 @OperatorID int,
 @StartDate  datetime,
 @EndDate datetime
as
--=============================================================================
-- 2012.07.12 DE10568 jkn add Address2 to the results for the Address
--=============================================================================

select convert(varchar(8),pli.FirstVisitDate,1) as [Join Date], 
    pli.PlayerID as [Player ID],
    p.LastName+ ', ' +p.FirstName as [Name],
    case when len (a.Address2) > 0 then a.Address1 + '   ' + a.Address2
    else a.Address1 end as [Address],
    a.City,
    a.[State],
    a.Zip,
    p.Phone as [Phone Number],
    p.Email as [Email Address],
    p.Gender,
    pli.VisitCount as [Visit],
    pli.OperatorID,
    Op.OperatorName,
    pb.pbTotalSpentAmt as [Spend]
from dbo.PlayerInformation pli  
    join player p on p.playerID = pli.playerID
    left join [Address] A on p.addressID = A.AddressID
    join PointBalances pb on pb.pbPointBalancesID = pli.PointBalancesID
    join Operator Op on Op.OperatorID = pli.OperatorID
where pli.FirstVisitDate is not null
    and(Op.OperatorID = @OperatorID or @OperatorID = 0)
    AND pli.FirstVisitDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
    AND pli.FirstVisitDate <= dateadd(day,1,cast(convert(varchar(12), @EndDate, 101) as smalldatetime))
order by pli.FirstVisitDate asc






GO

