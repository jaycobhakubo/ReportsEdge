USE [Daily]
GO

/****** Object:  View [dbo].[view_GetMachineHistory]    Script Date: 12/31/2013 20:17:00 ******/
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[view_GetMachineHistory]'))
DROP VIEW [dbo].[view_GetMachineHistory]
GO

USE [Daily]
GO

/****** Object:  View [dbo].[view_GetMachineHistory]    Script Date: 12/31/2013 20:17:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE View [dbo].[view_GetMachineHistory] As
Select  Case
			When ul.ulSoldToMachineID is null Then ROW_NUMBER() Over(Partition By ul.ulUnitSerialNumber Order By ul.ulRegisterReceiptID)
				Else ROW_NUMBER() Over(Partition By ul.ulSoldToMachineID Order By ul.ulRegisterReceiptID) 
				End As RowID,
		ul.ulGamingDate,
		ul.ulDeviceID,
		ul.ulPackNumber,
		ul.ulUnitNumber,
		ul.ulUnitSerialNumber,
		ul.ulRegisterReceiptID,
		TransactionNumber,
		ul.ulSoldToMachineID,
		isnull(ul.ulUnlockDate, ul.ulPackLoginAssignDate) as DTStamp,
		Case
			When ul.ulUnlockDate is null Then 'Pack Entered'
				Else 'Pack Removed'
			End as TransactionType
From UnLockLog ul join RegisterReceipt r on ul.ulRegisterReceiptID = r.RegisterReceiptID
Where ulDeviceID > 2



GO

