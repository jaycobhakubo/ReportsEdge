USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerList]    Script Date: 05/01/2012 14:57:26 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerList]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerList]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerList]    Script Date: 05/01/2012 14:57:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
CREATE PROCEDURE [dbo].[spRptPlayerList]     
-- =============================================  
-- Author:  GameTech  
-- Description: Print mailing labels for VIP players  
--  
-- BJS 10/05/2011: DE9192 cols 2 and 3 offset (unable to run report w/in Crystal due to param mismatch) 
-- KC 5/2/2012: DE9843 Fixed  Match the Spend and Visits for a 
--    player in the report to the player information displayed when you look up the player
-- =============================================  
 @OperatorID as int,    
 @Birthday as bit,    
 @BDFrom as Datetime,      -- DE9192  
 @BDEnd as Datetime,    
 @Gender as Bit,    
 @GenderType as nvarchar(4),    
 @PointsBalance as bit,    
 @Min as Money,    
 @Max as Money,    
 @LastVisit as bit,    
 @LVStart as Datetime,    
 @LVEnd as Datetime,    
 @Spend as bit,    
 @Average as Bit,    
 @AmountFrom as money,    
 @AmountTo as money,    
 @StartDate as Datetime,    
 @EndDate as Datetime,    
 @Status  as Bit,    
 @StatusID as Int    
AS    
SET NOCOUNT ON    
      set @BDFrom = CONVERT(varchar(12),@BDFrom, 10) 
    set  @BDEnd = CONVERT(varchar(12),@BDEnd , 10)

    set @StartDate = CONVERT(varchar(12),@StartDate, 10)
     set @EndDate  = CONVERT(varchar(12),@EndDate, 10)

    
DECLARE @OperatorsSharePoints varchar(30),    
  @OperatorsShareCredit varchar(30),  
  @StatusName NVARCHAR(64)  
    
SELECT @OperatorsSharePoints = (SELECT SettingValue FROM GlobalSettings WHERE GlobalSettingID = 180)    
SELECT @OperatorsShareCredit = (SELECT SettingValue FROM GlobalSettings WHERE GlobalSettingID = 145)  
  
IF @Status = 1  
BEGIN  
 SELECT @StatusName = StatusName  
 FROM PlayerStatusCode  
 WHERE PlayerStatusCodeID = @StatusID  
END  
ELSE  
BEGIN  
 SET @StatusName = ''  
END  
    
set @LVEnd = Dateadd(Day,1,@LVEnd)    
--set @EndDate = Dateadd(Day,1,@EndDate)    ---DE9843 removed kc 5/1/2012
    
Create Table #TempPlayerList    
 (FirstName nvarchar(32),     
 MiddleInitial nvarchar(4),     
 LastName nvarchar(32),     
 PlayerID int,     
 Birthdate datetime,   -- DE9192  
 Email nvarchar(200),     
 Gender nvarchar(4),    
 Address1 nvarchar(64),     
 Address2 nvarchar(64),     
 City nvarchar(32),     
 State nvarchar(32),     
 Country nvarchar(32),     
 Zip nvarchar(32),    
 Refundable money,     
 NonRefundable money,    
 LastVisitDate datetime,   -- DE9192  
 PointsBalance money,     
 OperatorID int,    
 Spend money,     
 Visits int,    
 AvgSpend money)    
     
 -- INSERT ALL Players into this temporary table    
 INSERT INTO #TempPlayerList    
 (FirstName, MiddleInitial, LastName, PlayerID, Birthdate, Email, Gender, Address1, Address2, City, State, Country, Zip,    
  Refundable, NonRefundable, LastVisitDate, PointsBalance, OperatorID, Spend, Visits, AvgSpend)  
 SELECT p.FirstName, p.MiddleInitial, p.LastName, p.PlayerID, p.BirthDate, p.EMail, p.Gender, a.Address1, a.Address2, a.City, a.State, a.Country, a.Zip,    
 '0.00', '0.00', '01/01/1900', '0.00', @OperatorID, '0.00', 0, '0.00'   
 FROM Player p    
 left JOIN Address a ON (p.AddressID = a.AddressID)    
     
 -- Depending on the share credit setting, update credit    
 IF (@OperatorsShareCredit LIKE '%t%')    
 BEGIN    
  UPDATE #TempPlayerList    
  SET Refundable = ISNULL((SELECT TOP 1 cb.Refundable    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN CreditBalances cb ON (pli.CreditBalancesID = cb.CreditBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         ORDER BY cb.Refundable), '0.00'),    
   NonRefundable = ISNULL((SELECT TOP 1 cb.NonRefundable    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN CreditBalances cb ON (pli.CreditBalancesID = cb.CreditBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         ORDER BY cb.NonRefundable), '0.00')             
  FROM #TempPlayerList tpl    
 END    
 ELSE    
 BEGIN    
  UPDATE #TempPlayerList    
  SET Refundable = ISNULL((SELECT TOP 1 cb.Refundable    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN CreditBalances cb ON (pli.CreditBalancesID = cb.CreditBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         AND pli.OperatorID = @OperatorID    
         ORDER BY cb.Refundable), '0.00'),    
   NonRefundable = ISNULL((SELECT TOP 1 cb.NonRefundable    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN CreditBalances cb ON (pli.CreditBalancesID = cb.CreditBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         AND pli.OperatorID = @OperatorID    
         ORDER BY cb.NonRefundable), '0.00')             
  FROM #TempPlayerList tpl      
 END    
    
     
 -- Depending on the share points setting, update points, spend, visits, avgspend, status, statuscode    
 IF (@OperatorsSharePoints LIKE '%t%')     
 BEGIN    
  UPDATE #TempPlayerList    
  SET PointsBalance = ISNULL((SELECT TOP 1 pb.pbPointsBalance    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN PointBalances pb ON (pli.PointBalancesID = pb.pbPointBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         ORDER BY pb.pbPointsBalance), '0.00'),    
   LastVisitDate = ISNULL((SELECT TOP 1 pli.LastVisitDate    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         WHERE p.PlayerID = tpl.PlayerID    
         ORDER BY pli.LastVisitDate desc), '01/01/1900'),    
   Visits   = (SELECT Count(DISTINCT rr.GamingDate)    
         FROM Player p    
         JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)
         --DE9843 5/1/2012 kc
         where p.PlayerID = tpl.PlayerID 
         and (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate ) 
         --DE9843 5/1/2012 kc
         ),    
   Spend   = (SELECT ISNULL(SUM(rd.Quantity * rd.PackagePrice), '0.00')    
          FROM Player p    
          JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)    
          JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
          WHERE p.PlayerID = tpl.PlayerID    
          AND rd.VoidedRegisterReceiptID IS NULL    
          AND ((@Spend = 0)     
                OR     
                (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
                 AND    
                 rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))),                    
   AvgSpend  = (SELECT ISNULL((SUM(rd.Quantity * rd.PackagePrice) / Count(Distinct(rr.GamingDate))), '0.00')    
        FROM Player p    
        JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)    
        JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
        WHERE p.PlayerID = tpl.PlayerID    
        AND rd.VoidedRegisterReceiptID IS NULL    
        AND ((@Average = 0)    
              OR    
                (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
                 AND    
                 rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))))                  
  FROM #TempPlayerList tpl       
 END    
 ELSE    
 BEGIN    
  UPDATE #TempPlayerList    
  SET PointsBalance = ISNULL((SELECT TOP 1 pb.pbPointsBalance    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         JOIN PointBalances pb ON (pli.PointBalancesID = pb.pbPointBalancesID)    
         WHERE p.PlayerID = tpl.PlayerID    
         AND pli.OperatorID = @OperatorID    
         ORDER BY pb.pbPointsBalance), '0.00'),    
   LastVisitDate = ISNULL((SELECT TOP 1 pli.LastVisitDate    
         FROM Player p    
         JOIN PlayerInformation pli ON (p.PlayerID = pli.PlayerID)    
         WHERE p.PlayerID = tpl.PlayerID    
         AND pli.OperatorID = @OperatorID    
         ORDER BY pli.LastVisitDate desc), '01/01/1900'),    
   Visits   = (SELECT Count(DISTINCT rr.GamingDate)    
         FROM Player p    
         JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)    
         WHERE rr.OperatorID = @OperatorID
         --DE9843 kc 5/1/2012
                  and  p.PlayerID = tpl.PlayerID 
         and  (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate ) ), 
         --DE9843 kc 5/1/2012),    
   Spend   = (SELECT ISNULL(SUM(rd.Quantity * rd.PackagePrice), '0.00')    
          FROM Player p    
          JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)    
          JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
          WHERE p.PlayerID = tpl.PlayerID    
          AND rr.OperatorID = @OperatorID    
          AND rd.VoidedRegisterReceiptID IS NULL    
          AND ((@Spend = 0)     
                OR     
                (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
                 AND    
                 rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))),              
   AvgSpend  = (SELECT ISNULL((SUM(rd.Quantity * rd.PackagePrice) / Count(Distinct(rr.GamingDate))), '0.00')    
        FROM Player p    
        JOIN RegisterReceipt rr ON (p.PlayerID = rr.PlayerID)    
        JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
        WHERE p.PlayerID = tpl.PlayerID    
        AND rr.OperatorID = @OperatorID    
        AND rd.VoidedRegisterReceiptID IS NULL    
        AND ((@Average = 0)    
              OR    
                (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
                 AND    
                 rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))))                                            
  FROM #TempPlayerList tpl     
 END    
    
 set @LVEnd = Dateadd(Day,1,@LVEnd)    
 --set @EndDate = Dateadd(Day,1,@EndDate)    
    
 Create Table #TempPlayer    
  (FirstName nvarchar(32),     
  MiddleInitial nvarchar(4),     
  LastName nvarchar(32),     
  PlayerID int,     
  Birthdate datetime,     -- DE9192  
  Email nvarchar(200),     
  Gender nvarchar(4),    
  Address1 nvarchar(64),     
  Address2 nvarchar(64),     
  City nvarchar(32),     
  State nvarchar(32),     
  Country nvarchar(32),     
  Zip nvarchar(32),    
  Refundable money,     
  NonRefundable money,    
  LastVisitDate datetime,     -- DE9192  
  PointsBalance money,     
  OperatorID int,    
  Spend money,     
  Visits int,    
  AvgSpend money,    
  StatusName nvarchar(64))    


insert into #tempPlayer    
 (FirstName, MiddleInitial, LastName, PlayerID, Birthdate, Email, Gender,    
   Address1, Address2, City, [State], Country, Zip,    
  Refundable, NonRefundable,    
  LastVisitDate, PointsBalance, PIN.OperatorID,    
 Spend, Visits, AvgSpend, StatusName)    
 


SELECT tpl.FirstName, tpl.MiddleInitial, tpl.LastName, tpl.PlayerID, tpl.Birthdate, tpl.Email, tpl.Gender, tpl.Address1, tpl.Address2, tpl.City,    
  tpl.State, tpl.Country, tpl.Zip, tpl.Refundable, tpl.NonRefundable, tpl.LastVisitDate, tpl.PointsBalance, tpl.OperatorID, tpl.Spend,    
  tpl.Visits, tpl.AvgSpend, @StatusName
FROM #TempPlayerList tpl    
 
WHERE (@Birthday = 0 

or 
 (cast(convert(varchar(110),tpl.Birthdate,10)as smalldatetime) >= cast(CONVERT(varchar(110),@BDFrom, 10)as smalldatetime)  
and cast(convert(varchar(110),tpl.Birthdate,10)as smalldatetime) <= cast(CONVERT(varchar(110),@BDEnd , 10) as smalldatetime)
) )  
  
and (@Gender = 0 or tpl.Gender = @GenderType)     
and (@PointsBalance = 0 or tpl.PointsBalance >= @Min and tpl.PointsBalance <= @Max)    
and (@LastVisit = 0 or tpl.LastVisitDate >= CAST(CONVERT(varchar(12), @LVStart, 101) AS smalldatetime)     
  and tpl.LastVisitDate <= CAST(CONVERT(varchar(12), @LVEnd, 101) AS smalldatetime))  
-- DE7912 - Collect all the player's statuses (and potentially filter them out).  
and (@Status = 0 or EXISTS(SELECT 1 FROM PlayerStatus WHERE PlayerID = tpl.PlayerID AND PlayerStatusCodeID = @StatusID))  
    

    
IF @Spend = 1    
 SELECT    
  PlayerID,    
  FirstName,    
  MiddleInitial,    
  LastName,    
  BirthDate,    
  Email,    
  Gender,    
  Address1,    
  Address2,    
  City,    
  State,    
  Country,    
  Zip,    
  Refundable,    
  NonRefundable,    
  LastVisitDate,    
  PointsBalance,    
  Spend,    
  AvgSpend,    
  Visits,    
  StatusName,    
  OperatorID --JLW 7-29-2009 Added OperatoriD to select    
 FROM    
  #TempPlayer    
 WHERE    
  (Spend >= @AmountFrom AND    
  Spend <= @AmountTo)    
 -- and Spend <> 0
 ORDER BY PlayerID asc   
  --LastName    
 --ASC    
ELSE IF @Average = 1    
 SELECT    
  PlayerID,    
  FirstName,    
  MiddleInitial,    
  LastName,    
  BirthDate,    
  Email,    
  Gender,    
  Address1,    
  Address2,    
  City,    
  State,    
  Country,    
  Zip,    
  Refundable,    
  NonRefundable,    
  LastVisitDate,    
  PointsBalance,    
  Spend,    
  AvgSpend,      Visits,    
  StatusName,    
  OperatorID  --JLW 7-29-2009 Added OperatoriD to select    
 FROM    
  #TempPlayer    
 WHERE    
  (AvgSpend >= @AmountFrom AND    
  AvgSpend <= @AmountTo )
 -- and AvgSpend <> 0   
 ORDER BY PlayerID asc   
  --LastName 
 --ASC    
ELSE    
 SELECT    
  PlayerID,    
  FirstName,    
  MiddleInitial,    
  LastName,    
  BirthDate,    
  Email,    
  Gender,    
  Address1,    
  Address2,    
  City,    
  State,    
  Country,    
  Zip,    
  Refundable,    
  NonRefundable,    
  LastVisitDate,    
  PointsBalance,    
  Spend,    
  AvgSpend,    
  Visits,    
  StatusName,    
  OperatorID  --JLW 7-29-2009 Added OperatoriD to select    
 FROM    
 #TempPlayer  
 ORDER BY PlayerID asc   
  --LastName   
 --ASC    
    
Drop table #tempPlayer    
Drop table #TempPlayerList    

    
    
    
    
    
  




    
SET NOCOUNT OFF    
    
    
    
    
    
    
  
  
GO


