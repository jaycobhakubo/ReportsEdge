--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'PlayerSpendTop100.rpt')
begin
    insert into Reports values (3, 1, 'PlayerSpendTop100.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);        -- Insert Report Parameters

    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (4, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Player Spend Top 100');
end