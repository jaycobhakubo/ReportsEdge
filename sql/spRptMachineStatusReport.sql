USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptMachineStatusReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptMachineStatusReport]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptMachineStatusReport]
	
AS
BEGIN
	SET NOCOUNT ON;
	 SELECT D.DeviceID, D.DeviceType, MachineDescription, InUse, IsCleared,
		P.FirstName, P.MiddleInitial, P.LastName,
		S.FirstName, S.LastName, IsAssigned,
		LockStatus, ClientIdentifier, IsOnline, M.IsActive, M.MachineID,
		OperatorID, LoggedIn, LoggedOut
	 FROM   Machine M (nolock) 
	JOIN MachineStatus MS ON M.MachineID= MS.MachineID 
	JOIN Device D ON M.DeviceID = D.DeviceID 
	LEFT JOIN Player P ON MS.PlayerID = P.PlayerID
	left Join Staff S on MS.StaffID = S.StaffID
   END

GO


