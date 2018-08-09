-- AddPositionPermissionDetail.sql   
-- US1956

use daily;
go

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;


select @reporttypeId = Reporttypeid from ReportTypes where TypeName = 'Special';
select @reportid = ReportID from Reports where ReportFileName = 'PositionPermissionDetail.rpt';

if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'PositionPermissionDetail.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'PositionPermissionDetail.rpt';
end;


select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Position Permission Detail');
end

select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
if(@reportparamid is null)
begin
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 1); -- opid
end;

select * from Reports where ReportID = @reportid;
select * from ReportDefinitions where ReportID = @reportid;
select * from ReportLocalizations where ReportID = @reportid;

select r.*, rd.*, rp.ParameterName, rl.*, rt.TypeName
from reports r
join ReportDefinitions rd on r.ReportID = rd.ReportID
join ReportParameters rp on rd.ReportParameterID = rp.ReportParameterID
join ReportLocalizations rl on r.ReportID = rl.ReportID
join ReportTypes rt on rt.ReportTypeID = r.ReportTypeID
where ReportFileName like 'PositionPermissionDetail.rpt';

