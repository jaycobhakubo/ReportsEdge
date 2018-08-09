USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRaffleEntrants]    Script Date: 04/12/2012 15:59:26 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRaffleEntrants]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRaffleEntrants]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRaffleEntrants]    Script Date: 04/12/2012 15:59:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--------------------
--------------------
--Karlo Camacho
--4/12/2012
----------------------
-----------------------


create proc [dbo].[spRptRaffleEntrants]

 @OperatorId INT 
AS  
SET NOCOUNT ON  
  

  
    SELECT 
PR.EntryTime as [Entry Date],
PR.PlayerID as [Player ID] ,
case
when p.LastName Like '' and p.Firstname Like '' then ''
else
p.LastName+', '+p.FirstName end as [Name], 
a.Address1 as [Address],
a.City,
a.[State],
a.Zip,
p.Phone as [Phone Number],
p.Email as [Email Address]


FROM PlayerRaffle PR WITH (NOLOCK)  
 JOIN Player P WITH (NOLOCK) ON PR.PlayerID = P.PlayerID  
 join [Address] A on A.AddressID = P.AddressID 
WHERE PR.OperatorId = @OperatorId  

 set nocount off
GO


