--- Insert Report Script
use Daily;

-- Report Groups
-- 1 = Sales	6 = Special		11 = Tax Forms		16 = Texas
-- 2 = Paper	7 = Bingo		12 = Gaming			17 = Coupon
-- 3 = Player	8 = Electronics 13 = Inventory		18 = B3
-- 4 = Misc		9 = Exceptions	14 = Progressives
-- 5 = Staff	10 = Customer	15 = Payouts

if not exists (select * from Reports where ReportFileName = 'Packages.rpt')
begin

    insert into Reports values (4, 1, 'Packages.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);        -- Insert Report Parameters

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Packages');
end