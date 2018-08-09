use Daily
go

declare @rptIDStaff int

select	@rptIDStaff = ReportID 
from	Reports 
where	ReportFileName = 'StaffReport.rpt';

if exists
	(
		select 1
		from	ReportDefinitions
		where	ReportID = @rptIDStaff and ReportParameterID = 53
	)
	begin
		delete from ReportDefinitions where ReportID = @rptIDStaff and ReportParameterID = 53
	end;

if not exists 
	(
		select	1
		from	ReportDefinitions 
		where	ReportID = @rptIDStaff and ReportParameterID = 64
	)
	begin
		insert into ReportDefinitions (ReportParameterID, ReportID)
		values (64, @rptIDStaff)
	end;