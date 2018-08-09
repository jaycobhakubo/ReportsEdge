--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'CannerySessionSummaryRecap.rpt')
begin
    insert into Reports values (1, 0, 'CannerySessionSummaryRecap.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);        -- Insert Report Parameters

    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (4, @ReturnValue);
    
    insert into ReportDefinitions values (5, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Session Summary Recap');
end