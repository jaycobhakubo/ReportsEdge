--- Insert Payout Summary Report
Use Daily;

if not exists (select 1 from Reports where ReportFileName = 'PayoutSummaryReport.rpt')
begin
    insert into Reports values (15, 1, 'PayoutSummaryReport.rpt');

    declare @ReturnValue int;

    select @ReturnValue = scope_identity ();

    insert into ReportDefinitions values (1, @ReturnValue);

    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (4, @ReturnValue);

    insert into ReportDefinitions values (5, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Payout Summary');
end
