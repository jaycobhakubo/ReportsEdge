USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindElectronicSales]    Script Date: 06/10/2015 16:30:20 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindElectronicSales]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindElectronicSales]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindElectronicSales]    Script Date: 06/10/2015 16:30:21 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		FortuNet
-- Create date: 5/21/2013
-- Description:	Find sales data for each electronic transaction. 
-- Returns: Receipt Number, Pack Number, Device Type, Client ID, Serial Number, Card Count, Electronic Sales Amount, etc.
-- TMP 2014.01.03:  Added RegisterReceiptID to the resultset.
-- 2014.11.04 tmp: DE12125 Sum(CardCount) and Group By statement caused the SalesAmount to be incorrect.
-- 2015.06.10 tmp: US4017 Add support for multiple game categories.
-- =============================================
CREATE FUNCTION [dbo].[FindElectronicSales] 
(
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME,
	@Session		AS INT
)
RETURNS 
@ElectronicSales TABLE 
(

	GamingDate DateTime,
	SessionPlayedID int,
	GamingSession int,
	RegisterReceiptID int,
	ReceiptNumber int,
	TransactionDTS DateTime,
	OriginalRegisterReceiptID int,
	VoidedRegisterReceiptID int,
	StaffID int,
	PackNumber int,
	MachineID int,
	ClientIdentifier nvarchar(64),
	SerialNumber nvarchar(64),
	DeviceID int,
	DeviceName nvarchar(32),
	CardsSold int,
	SalesAmount money
)

AS
BEGIN
	-- Temp table to determine number of games played by game category for each session...
	Declare @NbrGamesPlayed table
	(
		SessionPlayedID Int,
		NbrGames Int,
		GameCategoryID Int
	)
	Insert @NbrGamesPlayed
	Select sgp.SessionPlayedID,
		Count(Distinct sgp.DisplayGameNo) as NbrGames,
		sgc.GameCategoryID as GameCategory           -- US4000
	From SessionGamesPlayed sgp
	Join SessionPlayed sp on (sgp.SessionPlayedID = sp.SessionPlayedID)
	join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId  -- US4000
	Where sgp.IsContinued = 0 -- False
	And sp.OperatorID = @OperatorID
	And sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND (@Session = 0 or sp.GamingSession = @Session)
	Group By sgc.GameCategoryID, sgp.SessionPlayedID;    -- US4000

--------------------------------------------------------------------------------------------
--- Insert the Packages and Products sold for each transaction -----------------------------
	Declare @CardCount TABLE 
	(
		GamingDate DateTime,
		RegisterReceiptID int,
		StaffID int,
		PackNumber int,
		ReceiptNumber int,
		TransactionDTS DateTime,
		OriginalRegisterReceiptID int,
		VoidedRegisterReceiptID int,
		PackageName nvarchar(64),
		PackagePrice money,
		PkgQty int,
		ProductItemName nvarchar(64),
		PrdQty int,
		PrdPrice money,
		CardCount int,
		GameCategoryID int,
		SessionPlayedID int,
		GamingSession int,
		DeviceID int,
		MachineID int,
		SerialNumber nvarchar(15)
	)
	Insert @CardCount
	Select	rr.GamingDate,
			rd.RegisterReceiptID,
			rr.StaffID,
			rr.PackNumber,
			rr.TransactionNumber,
			rr.DTStamp,
			rr.OriginalReceiptID,
			rd.VoidedRegisterReceiptID,	
			rd.PackageName,
			rd.PackagePrice,
			rd.Quantity as PkgQty,
			rdi.ProductItemName,
			rdi.Qty as PrdQty,
			rdi.Price as PrdPrice,
	--		sum(rdi.CardCount), -- DE12125
			rdi.CardCount,		-- DE12125
			rdi.GameCategoryID,
			sp.SessionPlayedID,
			sp.GamingSession,
			(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
			(SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
			rr.UnitSerialNumber
	From RegisterDetail rd
	Join RegisterReceipt rr on (rd.RegisterReceiptID = rr.RegisterReceiptID)
	Join RegisterDetailItems rdi on (rd.RegisterDetailID = rdi.RegisterDetailID)
	Join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
	Where rr.OperatorID = @OperatorID
	And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And rr.SaleSuccess = 1
	And rdi.CardMediaID = 1 -- Electronic
	AND (@Session = 0 or sp.GamingSession = @Session)
-- DE12125	Group By rd.RegisterReceiptID, rr.TransactionNumber, rr.OriginalReceiptID, rd.VoidedRegisterReceiptID, rr.PackNumber, rd.PackageName, rd.PackagePrice, rd.Quantity, rdi.ProductItemName, rdi.Qty, rdi.Price, rdi.GameCategoryID, rdi.CardCount, sp.SessionPlayedID, sp.GamingSession, rr.GamingDate, rr.StaffID, rr.DTStamp, rr.UnitSerialNumber;

	--Select * From @CardCount

---------------------------------------------------------------------------------------------
--- Insert the Voided Transactions ----------------------------------------------------------

	Insert @CardCount
	Select	rr.GamingDate,
			rr.RegisterReceiptID,
			rr.StaffID,
			rr.PackNumber,
			rr.TransactionNumber,
			rr.DTStamp,
			rr.OriginalReceiptID,
			Null,	
			rd.PackageName,
			rd.PackagePrice,
			rd.Quantity as PkgQty,
			rdi.ProductItemName,
			rdi.Qty as PrdQty,
			rdi.Price as PrdPrice,
	--		sum(rdi.CardCount), -- DE12125
			rdi.CardCount,		-- DE12125
			rdi.GameCategoryID,
			sp.SessionPlayedID,
			sp.GamingSession,
			(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
			(SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
			rr.UnitSerialNumber
	From RegisterDetail rd
	Join RegisterReceipt rr on (rd.RegisterReceiptID = rr.OriginalReceiptID)
	Join RegisterDetailItems rdi on (rd.RegisterDetailID = rdi.RegisterDetailID)
	Join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
	Where rr.OperatorID = @OperatorID
	And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And rr.TransactionTypeID = 2 -- Sale Void
	And rdi.CardMediaID = 1 -- Electronic
	AND (@Session = 0 or sp.GamingSession = @Session)
-- DE12125	Group By rr.RegisterReceiptID, rr.TransactionNumber, rr.OriginalReceiptID, rd.VoidedRegisterReceiptID, rr.PackNumber, rd.PackageName, rd.PackagePrice, rd.Quantity, rdi.ProductItemName, rdi.Qty, rdi.Price, rdi.GameCategoryID, rdi.CardCount, sp.SessionPlayedID, sp.GamingSession, rd.RegisterReceiptID, rr.GamingDate, rr.StaffID, rr.DTStamp, rr.UnitSerialNumber;

------------------------------------------------------------------------------------------------	
--- Add the PackNumber to the voided transaction -----------------------------------------------
	
	Update @CardCount
	Set PackNumber = (Select rr.PackNumber From RegisterReceipt rr where OriginalRegisterReceiptID = rr.RegisterReceiptID)
	Where PackNumber is null
	
-------------------------------------------------------------------------------------------------
--- Add the SerialNumber to the voided transaction ----------------------------------------------

	Update @CardCount
	Set SerialNumber = (Select rr.UnitSerialNumber From RegisterReceipt rr where OriginalRegisterReceiptID = rr.RegisterReceiptID)
	Where DeviceID in (1, 2)
	AND SerialNumber is null

-------------------------------------------------------------------------------------------------
--- Now for out resultset -----------------------------------------------------------------------

	Insert into @ElectronicSales
	Select	cc.GamingDate,
			cc.SessionPlayedID,
			cc.GamingSession,
			cc.RegisterReceiptID,
			cc.ReceiptNumber,
			cc.TransactionDTS,
			cc.OriginalRegisterReceiptID,
			cc.VoidedRegisterReceiptID,
			cc.StaffID,
			cc.PackNumber,
			m.MachineID,
			m.ClientIdentifier,
			Case When d.DeviceID in (1,2) Then cc.SerialNumber
			When d.DeviceID > 2 Then m.SerialNumber End as SerialNumber,
			isnull(d.DeviceID, 0) as DeviceID,
			isnull(d.DeviceType, 'Pack') as DeviceName,
			Sum((ngp.NbrGames * cc.CardCount * cc.PrdQty) * cc.PkgQty) as CardsSold,
			Sum(PrdPrice * PrdQty * PkgQty)as SalesAmount
	From @CardCount cc
	Join @NbrGamesPlayed ngp on (cc.GameCategoryID = ngp.GameCategoryID)
	Left Join Device d on (cc.DeviceID = d.DeviceID)
	Left Join Machine m on (cc.MachineID = m.MachineID)
	Where cc.SessionPlayedID = ngp.SessionPlayedID
	Group By cc.GamingDate, cc.SessionPlayedID, cc.GamingSession, cc.RegisterReceiptID, cc.ReceiptNumber, cc.OriginalRegisterReceiptID, cc.VoidedRegisterReceiptID, cc.PackNumber, m.MachineID, m.ClientIdentifier, m.SerialNumber, d.DeviceID, d.DeviceType, cc.StaffID, cc.TransactionDTS, cc.SerialNumber;	

	-- This statement will return the table variable to the caller
	RETURN 
END













GO

