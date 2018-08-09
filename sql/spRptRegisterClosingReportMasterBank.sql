USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportMasterBanks]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportMasterBanks]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


  
CREATE PROCEDURE [dbo].[spRptRegisterClosingReportMasterBanks]  

 -- =============================================  
-- Author:  Fortunet  
-- Description: Report master bank activity.
--   
-- =============================================  
(  
 @OperatorId  as int,  
 @StartDate as datetime,  
 @EndDate  as datetime,  
 @StaffID  as int,  
 @Session  as int,  
 @MachineID as int  
)  
 as
 SET NOCOUNT ON;   
 
 begin

--=======================================
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
 --set @StartDate = '10/28/2014 00:00:00'
 --set @EndDate = '10/28/2014 00:00:00'
 --set @StaffID = 26
 --set @Session = 1
 --set @MachineID = 0
  
--============================================
  
  
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
    GamingDate			DATETIME,  
    staffIdNbr          int,  
    staffLastName       NVARCHAR(64),  
    staffFirstName      NVARCHAR(64),  
	sessionNbr          int,  
	soldFromMachineId   int,  
    BanksIssuedTo		MONEY,  
    BanksIssuedFrom		MONEY,  
    DropsTo				MONEY,  
    DropsFrom			MONEY  
);  
  
-------------------------------------------------------  
--Master Banks  
-------------------------------------------------------  
  
-- Get banks issued to our staff member  
INSERT INTO @ClosingResults  
(  
		 gamingDate,   
		 sessionNbr,  
		 staffIdNbr,  
		 staffLastName, 
		 staffFirstName,  
		 soldFromMachineId,  
		 BanksIssuedTo  
)  
SELECT	ct.ctrGamingDate,  
		ct.ctrGamingSession,  
		s.StaffID, 
		s.LastName, 
		s.FirstName,  
		b.bkMachineID,  
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
FROM CashTransaction ct  
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
	JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
	AND b.bkOperatorID = @OperatorID -- Only include the specified operator's banks.  
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
	and (@StaffID = 0 or b.bkStaffID = @StaffID)  
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 )) 
	AND bkBankTypeID = 1  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID

-- Get banks issued from our staff member  
INSERT INTO @ClosingResults  
(  
		gamingDate,   
		sessionNbr,  
		staffIdNbr,  
		staffLastName, 
		staffFirstName,  
		soldFromMachineId,  
		BanksIssuedFrom  
)  
SELECT	ct.ctrGamingDate,  
		ct.ctrGamingSession,  
		s.StaffID, 
		s.LastName, 
		s.FirstName,  
		b.bkMachineId,  
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
	JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
	AND b.bkOperatorID = @OperatorID -- Only include the specified operator's banks.  
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only  
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
	and (@StaffID = 0 or b.bkStaffID = @StaffID)  	  
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
	AND bkBankTypeID = 1  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  
  

-- Get banks dropped to our staff member  
INSERT INTO @ClosingResults  
(  
		gamingDate,   
		sessionNbr,  
		staffIdNbr,  
		staffLastName, 
		staffFirstName,  
		soldFromMachineId,  
		DropsTo  
)  
SELECT  ct.ctrGamingDate,  
		ct.ctrGamingSession,  
		s.StaffID,
		s.LastName , 
		s.FirstName,  
		b.bkMachineID,  
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))  
FROM CashTransaction ct  
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)  
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
	JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
	AND b.bkOperatorID = @OperatorID -- Only include the specified operator's banks.  
	AND ct.ctrTransactionTypeID IN ( 20, 29) -- Bank Closes and Drops too  
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
	and (@StaffID = 0 or b.bkStaffID = @StaffID)  
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
	AND bkBankTypeID = 1  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  
  
-- Get banks dropped from our staff member  
INSERT INTO @ClosingResults  
(  
		gamingDate,   
		sessionNbr,  
		staffIdNbr,  
		staffLastName, 
		staffFirstName,  
		soldFromMachineId,  
		DropsFrom  
)  
SELECT	ct.ctrGamingDate,  
		ct.ctrGamingSession,  
        s.StaffID, 
        s.LastName, 
        s.FirstName,  
        b.bkMachineID,  
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  
FROM CashTransaction ct  
	 JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)  
	 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)  
	 JOIN Staff s ON (s.StaffID = b.bkStaffID)  
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks  
	 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks  
	 AND b.bkOperatorID = @OperatorID -- Only include the specified operator's banks.  
	 AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank Closes (implicit drops)  
	 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range  
	 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range  
	 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided  
	 and (@StaffID = 0 or b.bkStaffID = @StaffID)  
	 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))  
	 AND bkBankTypeID = 1  
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;  


Select	GamingDate,
		staffIdNbr,
		staffLastName,
		staffFirstName,
		sessionNbr,
		soldFromMachineId,
		SUM(Isnull(BanksIssuedTo, 0)) BanksIssuedTo,
		SUM(Isnull(BanksIssuedFrom, 0)) BanksIssuedFrom,
		SUM(Isnull(DropsTo, 0)) DropsTo,
		SUM(Isnull(DropsFrom, 0)) DropsFrom
From @ClosingResults
Group By GamingDate, sessionNbr, staffIdNbr, staffLastName, staffFirstName, soldFromMachineId;
 
End 
 
SET NOCOUNT OFF; 

GO

