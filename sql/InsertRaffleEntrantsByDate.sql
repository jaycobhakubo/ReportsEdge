--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'RaffleEntrantsByDate.rpt')
begin
    -- Report Type and Set IsActive
    
    insert into Reports values (3, 1, 'RaffleEntrantsByDate.rpt');   -- Player

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();
    
    -- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);		-- OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);		-- StartDate

    insert into ReportDefinitions values (4, @ReturnValue);		-- EndDate

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Raffle Entrants by Date');
end