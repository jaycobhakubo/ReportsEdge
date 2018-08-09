--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'BingoGameAnalysis.rpt')
begin
    insert into Reports values (7, 1, 'BingoGameAnalysis.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);  -- Insert Report Parameters, OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);  -- StartDate

    insert into ReportDefinitions values (4, @ReturnValue);  -- EndDate

    insert into ReportDefinitions values (5, @ReturnValue);  -- Session

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Bingo Game Analysis');
end