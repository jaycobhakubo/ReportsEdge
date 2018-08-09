-- FixUsers.sql 
-- Run this EACH time you restore from a db backup!

use Daily;
go

-- Info: show all users in current db
-- select * from sys.database_principals

exec sp_change_users_login @Action='Report';
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='RptUser';		-- cobalt$45
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='EliteUser';	-- sul$fur52
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='SQLUser'		-- gly*cine83
go
exec sp_changedbowner 'sa'
go

use History;
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='RptUser';
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='EliteUser';
go
exec sp_change_users_login @Action='Auto_Fix', @UserNamePattern='SQLUser'
go
exec sp_changedbowner 'sa'
go
