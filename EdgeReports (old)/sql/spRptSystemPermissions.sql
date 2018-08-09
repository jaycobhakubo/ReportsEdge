USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSystemPermissions]    Script Date: 02/08/2012 17:33:41 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSystemPermissions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSystemPermissions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSystemPermissions]    Script Date: 02/08/2012 17:33:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptSystemPermissions]
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - Detail report that list permissions for each position
--                     that has access to the system.
--
-- 2011.12.13 bsb: US1956 report creation
-- 2012.01.06 bsb: DE9620
-- 2012.02.08 bhendrix: DE10061
-- =============================================

AS
begin
	set nocount on;

	select p.PositionID as PositionID,
		m.ModuleID as ModuleID,
		p.PositionName as PositionName,
		m.ModuleName as ModuleName,
		m.ModuleDescription as ModuleDescription,
		mf.ModuleFeatureID as ModuleFeatureID,
		mf.ModuleFeatureName as ModuleFeatureName,
		mf.ModuleFeatureDescription as ModuleFeatureDescription,
		case when mp.PositionID is null then 0 else 1 end as ModulePermission,
		case when fp.PositionID is null then 0 else 1 end as FeaturePermission 
	from Position p
		cross join Modules m
		left join ModuleFeatures mf on (m.ModuleID = mf.ModuleID)
		left join ModulePermissions mp on (p.PositionID = mp.PositionID and m.ModuleID = mp.ModuleID)
		left join FeaturePermissions fp on (p.PositionID = fp.PositionID and mf.ModuleFeatureID = fp.ModuleFeatureID)
	where m.IsActive = 1 and p.PositionName <> 'GameTech Position'
	      and m.ModuleTypeID = 12
	order by PositionName, ModuleName, ModuleFeatureName;

end;




GO


