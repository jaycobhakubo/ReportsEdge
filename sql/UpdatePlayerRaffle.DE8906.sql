-- UpdatePlayerRaffle.DE8906.sql

use Daily;
go

if (not Exists(select * from sys.columns where Name = N'OperatorId' and Object_ID = Object_ID(N'PlayerRaffle')))
begin
    print 'Adding new foreign key: OperatorId'
    
    alter table PlayerRaffle add OperatorId int null;
    
    update PlayerRaffle set OperatorId = 1;

    alter table PlayerRaffle alter column OperatorId int not null;
    
end;
