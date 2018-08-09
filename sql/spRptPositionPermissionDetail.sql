USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPositionPermissionDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPositionPermissionDetail]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptPositionPermissionDetail] 
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - List positions with associated permissions.
--              Show application module functions and descriptions and staff with that permission.
--
-- 2011.10.13 bjs: US1956 report creation
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
    ModuleFeatureDescr  nvarchar(255),
    IsGTIStaffFeature   nvarchar(3)
    , StaffName           nvarchar(66)
    , StaffID             int
);

insert into @RESULTS 
select  
  o.OperatorID, o.OperatorName
  , p.PositionID, p.PositionName
  , m.ModuleID, m.ModuleName, m.ModuleDescription
  , mf.ModuleFeatureID, mf.ModuleFeatureName, mf.ModuleFeatureDescription
  , case when mf.IsGTIStaffFeature = 1 then 'Yes' else 'No' end
  , s.LastName + ', ' + s.FirstName [StaffName], s.StaffID
from Operator o 
join Position p on o.OperatorID = p.OperatorID
join StaffPositions sp on p.PositionID = sp.PositionID
join Staff s on sp.StaffID = s.staffID
join ModulePermissions mp on p.PositionID = mp.PositionID
join Modules m on mp.ModuleID = m.ModuleID
join FeaturePermissions fp on p.PositionID = fp.PositionID
join ModuleFeatures mf on fp.ModuleFeatureID = mf.ModuleFeatureID
where (@OperatorID = 0 or o.OperatorID = @OperatorID);

-- Return resultset
select * 
from @RESULTS
order by PositionName, ModuleName, ModuleFeatureName, StaffName, StaffID;

end;

SET NOCOUNT OFF
GO
