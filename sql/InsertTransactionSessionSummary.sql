--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'TransactionSessionSummary.rpt')
begin
    insert into Reports values (8, 1, 'TransactionSessionSummary.rpt');  

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);
    
    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (5, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Transaction Session Summary');
end