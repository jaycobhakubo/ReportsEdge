-- AddElectronicDeviceHistory.sql   
-- US1839

use daily;
go

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;


select @reporttypeId = Reporttypeid from ReportTypes where TypeName = 'Exceptions';
select @reportid = ReportID from Reports where ReportFileName = 'AuditReport.rpt';

if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'AuditReport.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'AuditReport.rpt';
end;


select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Audit Report');
end

select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
if(@reportparamid is null)
begin
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 1); -- OperatorID
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 3); -- startdate
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 4); -- enddate
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 5); -- session
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 38); -- serialnumber
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 61); -- serialnumber
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
where ReportFileName like 'AuditReport.rpt';

