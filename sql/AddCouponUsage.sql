use daily;
go

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;

declare @p1 int;
declare @p2 int;
declare @p3 int;
declare @p4 int;
declare @p5 int;

select @p1 = ReportParameterID from ReportParameters where ParameterName = '@OperatorID';
select @p2 = ReportParameterID from ReportParameters where ParameterName = '@PlayerID';
select @p3 = ReportParameterID from ReportParameters where ParameterName = '@CompID';

if not  exists(select Reporttypeid from ReportTypes where TypeName = 'Coupon')
begin
insert into ReportTypes values ('Coupon')-- reportID must be 17
end


select @reporttypeId = Reporttypeid from ReportTypes where TypeName = 'Coupon';
select @reportid = ReportID from Reports where ReportFileName = 'CouponUsage.rpt';

if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'CouponUsage.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'CouponUsage.rpt';
end;

select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Coupon Usage');
end


select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
if(@reportparamid is null)
begin
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p1); -- OperatorID
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p2); -- session
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p3); -- startdate

end;