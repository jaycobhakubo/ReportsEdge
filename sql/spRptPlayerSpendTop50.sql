USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendTop50]    Script Date: 05/14/2014 16:18:09 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerSpendTop50]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerSpendTop50]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendTop50]    Script Date: 05/14/2014 16:18:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptPlayerSpendTop50]

-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the top 50 players based on spend.
--				Logic is copied from spRptPlayerSpend
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate as smallDatetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

---------------------Testing--------------------------------------------------	
--Declare	
--	@OperatorID	as int,
--	@StartDate	as smalldatetime,
--	@EndDate as smallDatetime

--Set @OperatorID = 1
--Set @StartDate = '03/18/2014'
--Set @EndDate = '03/18/2014'
------------------------------------------------------------------------------
	
declare @spendTable table
(
		 xPlayerId int
		,xTotalSpend money
		,xAvgSpend money
)
    
insert into @spendTable select * from fnGetSpendAveragePerPlayer(@operatorId, @startDate, @endDate, default)

;with RESULTS
(FirstName, LastName, Address, City, State, Zip, PlayerID, OperatorID, MagneticCardNo, Spend, LastVisitDate)
as
(
    SELECT	FirstName, 
			LastName,
			a.Address1 + ' ' + a.Address2,
			a.City,
			a.State,
			a.Zip, 
			RR.PlayerID, 
			PIN.OperatorID, 
			PMC.MagneticCardNo,
			spend.xTotalSpend as spend,
			LastVisitDate
    FROM   PlayerInformation PIN (nolock) 
        JOIN  RegisterReceipt RR (nolock) on PIN.PlayerID = RR.PlayeriD
        JOIN Player P (nolock) ON PIN.PlayerID = P.PlayerID
        Left Join PlayerMagCards PMC (nolock) on PMC.PlayerID = P.PlayerID
        JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID
        join @spendTable spend on p.PlayerId = spend.xPlayerId
        left join Address a on a.AddressID = p.AddressID
    Where PIN.OperatorID = @OperatorID
        and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
        and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
        and RD.VoidedRegisterReceiptID is null
        and RR.SaleSuccess = 1
    group by  rr.PlayerID, FirstName, LastName, LastVisitDate, PIN.OperatorID, PMC.MagneticCardNo, spend.xTotalSpend, a.Address1, a.Address2, a.City, a.State, a.Zip
)

select	Top 50 Spend,
		FirstName, 
		LastName,
		Address,
		City,
		State,
		Zip, 
		PlayerID,
		MagneticCardNo, 
		LastVisitDate
from RESULTS
Order By Spend Desc;

END;

GO

