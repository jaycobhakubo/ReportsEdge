USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportCashActivity]    Script Date: 02/01/2013 09:35:37 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportCashActivity]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportCashActivity]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportCashActivity]    Script Date: 02/01/2013 09:35:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




  
  
  
  
  
  
  
  
CREATE PROCEDURE [dbo].[spRptRegisterClosingReportCashActivity]  
 (  
 -- =============================================  
-- Author:  Barry Silver  
-- Description: Receipt style closing report  
--    Show Bank balances.  
--  
-- 06/24/2011 bjs: implicit drops (close becomes a drop)  
-- 06/30/0211 bjs: show session 0 activity in other sessions  
-- 2011.07.05 bjs: DE8480 cash activity subrpt drops should match cash activity rpt  
-- 2011.07.07 bjs: DE8480 POS mode: staff bank issues only, MACHINE mode: master bank issues only  
-- 2011.07.20 bjs: Mohawk Beta fix for Session=NA  
-- 2011.11.08 bsb: DE9626 dispaly bank even if it's 0.00 
-- 1/28/2013 (knc): Add column for Cash Activity
-- =============================================  
  
 @OperatorId  as int,  
 @StartDate as datetime,  
 @EndDate  as datetime,  
 @StaffID  as int,  
 @Session  as int,  
 @MachineID as int  
  
)  
 as   
 begin  
  -- =======================================
  -- TEST
 -- begin
 --declare 
 --@OperatorId  as int,  
 --@StartDate as datetime,  
 --@EndDate  as datetime,  
 --@StaffID  as int,  
 --@Session  as int,  
 --@MachineID as int  
 
 --set @OperatorId = 1
 --set @StartDate = '1/17/2013 00:00:00'
 --set @EndDate = '1/17/2013 00:00:00'
 --set @StaffID = 0
 --set @Session = 0
 --set @MachineID = 0
  
  -- ============================================
  
  
  
 -- Verfify POS sending valid values  

declare @StaffID2 int
set @StaffID2 = @StaffID 

if @StaffID is null
begin
set @StaffID = isnull(@StaffID, 0);  
end
else
begin set @StaffID = 0 end
set @Session = isnull(@Session, 0);  
set @MachineID = isnull(@MachineID, 0);  


  
declare @ClosingResults  table  
(  
    GamingDate DATETIME,  
    staffIdNbr          int,  
    staffLastName       NVARCHAR(64),  
    staffFirstName      NVARCHAR(64),  
 sessionNbr          int,  
 soldFromMachineId   int,  
    BanksIssuedTo MONEY,  
    BanksIssuedFrom MONEY,  
    DropsTo MONEY,  
    DropsFrom MONEY  
);  
  
-------------------------------------------------------  
-- Banks  
-------------------------------------------------------  
  
declare @CashMethod int;  
select @CashMethod = CashMethodID from Operator  
where OperatorID = @OperatorID;  
  
-- FIX DE8853  
-- Money Center mode have true Master and Staff Banks.  Show only staff banks here (original code).  
if(@CashMethod = 3)  
begin  
  
-- Get banks issued to our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedTo  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineID,  
  SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  

FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
 AND bkBankTypeID = 2  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID  

--SELECT ct.ctrGamingDate,  
--  ct.ctrGamingSession,  
--        s.StaffID, s.LastName , s.FirstName,  
--        b.bkMachineID,  
--  SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
--  ,b.bkBankTypeID 
--FROM CashTransaction ct  
-- JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
-- JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
-- JOIN Staff s ON (s.StaffID = b.bkStaffID)  
--WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
-- AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
-- AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
-- AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
-- AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
-- AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
-- AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
--    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
--    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
-- and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
-- AND bkBankTypeID = 2  
--GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID  
--  ,b.bkBankTypeID 
  
  
-- Get banks issued from our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedFrom  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineId,  
  SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
 AND bkBankTypeID = 2  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  
  
 
  
-- Get banks dropped to our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 DropsTo  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineID,  
  SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN ( 20, 29) -- Bank Closes and Drops too  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
 AND bkBankTypeID = 2  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  
  
-- Get banks dropped from our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 DropsFrom  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineID,  
  SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank Closes (implicit drops)  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
 AND bkBankTypeID = 2  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;    
  
end  
else if(@CashMethod = 1)   -- POS mode  
begin  
-- POS Mode has banks, no drops  
  
-- Get banks issued to our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedTo  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineID,  
  SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    and (@MachineID = 0 or b.bkMachineID = @MachineID )   -- POS mode banks lack soldfrommachineid   
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  

 
  
-- Get banks issued from our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedFrom  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        s.StaffID, s.LastName , s.FirstName,  
        b.bkMachineId,  
  SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  
  
end  
else if(@CashMethod = 2)   -- MACHINE mode  
begin  
 print 'MACHINE MODE BANK ACTIVITY';  
-- MACHINE Mode has a shared master banks in a separate group.  No drops!  
  
-- Get banks issued to our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedTo  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        b.bkStaffID, 'Bank', 'Master',   
        b.bkMachineID,  
  SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
WHERE   
 b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;  
  
  
   --A
-- Get banks issued from our staff member  
INSERT INTO @ClosingResults  
(  
 gamingDate,   
 sessionNbr,  
    staffIdNbr,  
 staffLastName, staffFirstName,  
 soldFromMachineId,  
 BanksIssuedFrom  
)  
SELECT ct.ctrGamingDate,  
  ct.ctrGamingSession,  
        b.bkStaffID, 'Bank', 'Master',   
        b.bkMachineId,  
  SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
WHERE   
 b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;  
  
end; -- END MACHINE MODE  
 ----------------------
 --Adding column MasterBankType 
  
  select StaffID, b.bkBankTypeID, ctrGamingSession , ctrGamingDate    into #a
FROM CashTransaction ct  
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.  
 AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
    and (@StaffID = 0 or b.bkStaffID = @StaffID)  
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )      
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
 AND bkBankTypeID = 1;
  

  
  
with RESULTS(staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId, Banks, Drops) as  
(select staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId  
,SUM(isnull(BanksIssuedTo,0) + isnull(BanksIssuedFrom,0)) Banks  
-- ,SUM(isnull(DropsTo,0) + isnull(DropsFrom,0)) Drops DE8480  this may be changed in future if cash activity needs to display this data...  
,SUM(isnull(DropsFrom,0)) Drops   
from @ClosingResults   
group by staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId)  
select RESULTS.* , isnull(a.bkBankTypeID,2) bankTypeID into #b
from RESULTS  left join #a a on a.StaffID = RESULTS.staffIdNbr and a.ctrGamingSession = RESULTS.sessionNbr   and a.ctrGamingDate = RESULTS.GamingDate   
--where (Banks <> 0 or Drops <> 0) --DE9626  
ORDER BY staffIdNbr,gamingDate, sessionNbr ;  
  --26 row
  

  select b.* , isnull(Drops2,00.00) Drops2
  from #b b left join (select sum(b1.Drops) Drops2, b1.sessionNbr, b1.GamingDate, 1 bankTypeID  
from #b b1

where b1.bankTypeID <> 1 
group by b1.sessionNbr, b1.GamingDate ) x 
on x.bankTypeID = b.bankTypeID and x.GamingDate = b.GamingDate and x.sessionNbr = b.sessionNbr 
where (staffIdNbr = @StaffID2 or @StaffID2 = 0) 
  
    drop table #a
  drop table #b
  


End  
  
  
  



GO


