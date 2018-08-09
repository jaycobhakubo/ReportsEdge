USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPositionPermissionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPositionPermissionSummary]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptPositionPermissionSummary] 
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - List positions with associated permissions.
--              Show application module functions and descriptions, no staff.
--
-- 2011.10.21 bjs: US1956 report creation
-- =============================================
    @OperatorID    int 

as
begin
    
-- Temp table so Crystal can determine the shape of the output
declare @RESULTS table
(
    OperatorID          int,
    OperatorName        nvarchar(32),
    PositionId          int,
    PositionName        nvarchar(100),
    ModuleID            int,
    ModuleName          nvarchar(100),
    ModuleDescr         nvarchar(255),
    ModuleFeatureID     int,
    ModuleFeatureName   nvarchar(100),
    ModuleFeatureDescr  nvarchar(255)
);

insert into @RESULTS 
select  
  o.OperatorID, o.OperatorName
  , p.PositionID, p.PositionName
  , m.ModuleID, m.ModuleName, m.ModuleDescription
  , mf.ModuleFeatureID, mf.ModuleFeatureName, mf.ModuleFeatureDescription
from Operator o 
join Position p on o.OperatorID = p.OperatorID
join ModulePermissions mp on p.PositionID = mp.PositionID
join Modules m on mp.ModuleID = m.ModuleID
join FeaturePermissions fp on p.PositionID = fp.PositionID
join ModuleFeatures mf on fp.ModuleFeatureID = mf.ModuleFeatureID
where (@OperatorID = 0 or o.OperatorID = @OperatorID);

-- Return resultset
select * 
from @RESULTS
order by PositionName, ModuleName, ModuleFeatureName;

end;

SET NOCOUNT OFF
GO
