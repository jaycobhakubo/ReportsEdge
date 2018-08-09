USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRpt1042STaxRecipients]    Script Date: 09/07/2012 13:18:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRpt1042STaxRecipients]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRpt1042STaxRecipients]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRpt1042STaxRecipients]    Script Date: 09/07/2012 13:18:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <08/22/2012>
-- Description:	<W2G Tax Recipients>
-- 2012.08.24 tmp: Added a temp table to enter the results into.
-- =============================================
CREATE PROCEDURE [dbo].[spRpt1042STaxRecipients]
	(
	@OperatorID as Int,
	@StartDate as DateTime,
	@EndDate as DateTime
	)
AS
BEGIN
	
	SET NOCOUNT ON;

Declare @Temp1042S Table
(
	WagerType nvarchar(64),
	PlrFstName nvarchar(64),
	PlrMidInitial nvarchar(4),
	PlrLstName nvarchar(64),
	PlrAddr1 nvarchar(64),
	PlrAddr2 nvarchar(64),
	PlrCity nvarchar(32),
	PlrState nvarchar(32),
	PlrZip nvarchar(32),
	PlrCountry nvarchar(32),
	PlrGovID nvarchar(64),
	PlrSecID nvarchar(64),
	GrossTaxAmount money,
	FedTaxWithheld money,
	StateTaxWithheld money,
	MiscTaxWithheld money,
	WinningDate DateTime,
	CreatorID Int,
	CreatorFstName nvarchar(64),
	CreatorLstName nvarchar(64),
	CorrectorID Int,
	CorrectorFstName nvarchar(64),
	CorrectorLstName nvarchar(64),
	CorrectionDate DateTime
)
Insert into @Temp1042S
   SELECT
           ptf.WagerType,
           ptf.FirstName       [PlrFstName],
           ptf.MiddleInitial   [PlrMidInitial],
           ptf.LastName        [PlrLstName],
           a.Address1          [PlrAddr1],
           a.Address2          [PlrAddr2],
           a.City              [PlrCity],
           a.State             [PlrState],
           a.Zip               [PlrZip],
           a.Country           [PlrCountry],
           ptf.GovID           [PlrGovID],
           ptf.SecID           [PlrSecID],
           ptf.GrossTaxAmount,
           ptf.FedTaxWithheld,
           ptf.StateTaxWithheld,
           ptf.MiscTaxWithheld,
           ptf.WinningDate,
           ISNULL(s.StaffID, 0) [CreatorID],
           s.FirstName          [CreatorFstName],
           s.LastName           [CreatorLstName],
	       ISNULL(cs.StaffID, 0)[CorrectorID],
           cs.FirstName         [CorrectorFstName],
           cs.LastName          [CorrectorLstName],
           ptf.CorrectionDate

        FROM PlayerTaxForm ptf
		left join Address a ON ptf.AddressID = a.AddressID
		left join Staff s ON ptf.CreationStaffID = s.StaffID
		left join Staff cs ON ptf.CorrectionStaffID = cs.StaffID
		Where ptf.OperatorID = @OperatorID
		And ptf.WinningDate >= @StartDate
		And ptf.WinningDate <= @EndDate
		And ptf.TaxFormTypeID = 2

Select 
	WagerType,
	PlrFstName,
	PlrMidInitial,
	PlrLstName,
	PlrAddr1,
	PlrAddr2,
	PlrCity,
	PlrState,
	PlrZip,
	PlrCountry,
	PlrGovID,
	PlrSecID,
	GrossTaxAmount,
	FedTaxWithheld,
	StateTaxWithheld,
	MiscTaxWithheld,
	WinningDate,
	CreatorID,
	CreatorFstName,
	CreatorLstName,
	CorrectorID,
	CorrectorFstName,
	CorrectorLstName,
	CorrectionDate
From @Temp1042S  
END

GO

