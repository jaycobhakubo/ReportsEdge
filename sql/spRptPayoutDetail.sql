USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutDetail]    Script Date: 12/12/2013 15:03:15 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPayoutDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPayoutDetail]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutDetail]    Script Date: 12/12/2013 15:03:15 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--exec sp_helptext 'spRptPayoutDetail'
       
CREATE PROCEDURE  [dbo].[spRptPayoutDetail]         
(        
 --=============================================        
 ----Author:  Barry J. Silver        
 ----Description: Lists payouts made in a session        
        
 ----BJS - 05/25/2011  US1844 new report        
 ----DJR - 06/21/2011  DE8696 Non-bingo payouts not        
 ----     being returned.
 ----TMP - 11/15/2013	US2843 Add number of balls called
 ----TMP - 11/15/2013	US2842 Add last number called        
 --=============================================        
 @OperatorID AS INT,        
 @StartDate AS DATETIME,        
 @EndDate AS DATETIME,        
 @Session AS INT        
)        
AS        
BEGIN        
    SET NOCOUNT ON;        
--------------------        
--TEST        
--declare @OperatorID int, @StartDate datetime, @EndDate datetime, @Session int        
        
--set @OperatorID = 1        
--set @Session = 0        
--set @StartDate = '9/5/2000 00:00:00'
--set @EndDate = '9/5/2012 00:00:00'        
----------------------------------        
        
            
    -- Allow NULL (or zero as input) for requesting all        
    SET @Session = NULLIF(@Session, 0)        
    SET @OperatorID = NULLIF(@OperatorID, 0)        
        
    -- Temp table needed since we must track payouts AND accrual increases/payouts        
    declare @Results table        
    (        
         PlayerID int        
        ,PayoutTransID  INT        
        ,GamingDate   SMALLDATETIME        
        ,GamingSession  TINYINT        
        ,DisplayGameNo  INT        
        ,DisplayPartNo  NVARCHAR(50)        
        ,GCName    NVARCHAR(64)        
        ,StaffID   INT        
        ,MasterCardNumber INT        
        ,CardLevelName  NVARCHAR(32)        
        ,PayoutTypeName  NVARCHAR(32)        
        ,CashAmount   MONEY        
        ,CheckAmount  MONEY        
        ,CreditAmount  MONEY        
        ,MerchandiseAmount MONEY        
        ,OtherAmount  MONEY        
        ,CheckNumber  NVARCHAR(32)        
        ,PayoutTransNumber INT        
        ,VoidTransNumber INT        
        ,Payee    NVARCHAR(128)        
        ,PlayerName   NVARCHAR(66)        
        ,TransactionTypeID INT        
        ,TransactionType NVARCHAR(64)        
		,DTStamp   DATETIME
		,LastBallCall INT
		,BallCount INT            
    );        
        
 --        
 -- Insert all payout transactions with the criteria        
 -- requested        
 --        
 INSERT INTO @Results        
 (        
   PlayerID         
  ,PayoutTransID        
  ,GamingDate        
  ,StaffID        
  ,PayoutTransNumber        
  ,VoidTransNumber        
  ,PlayerName        
  ,TransactionTypeID        
  ,TransactionType        
  ,DTStamp        
 )        
 SELECT        
  p.PlayerID        
  ,p.PayoutTransID        
  ,p.GamingDate        
  ,p.StaffID        
  ,p.PayoutTransNumber        
  ,vp.PayoutTransNumber        
  ,CASE         
   WHEN (p.PlayerID IS NULL) THEN NULL        
   ELSE pl.LastName + ', ' + pl.FirstName        
   END        
  ,p.TransTypeID        
  ,tt.TransactionType        
  ,p.DTStamp        
 FROM PayoutTrans p        
  LEFT JOIN PayoutTrans vp ON (p.VoidTransID = vp.PayoutTransID)        
  LEFT JOIN Player pl ON (p.PlayerID = pl.PlayerID)        
  LEFT JOIN TransactionType tt ON (tt.TransactionTypeID = p.TransTypeID)        
 WHERE (@OperatorID IS NULL OR @OperatorID = p.OperatorID) AND        
   (p.GamingDate >= @StartDate) AND        
   (p.GamingDate <= @EndDate) AND        
   p.TransTypeID = 36 -- Only Payouts        
     

         
 --        
 -- Update records for Bingo Custom Session Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Custom' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)        
  JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)        
 --        
 -- Update records for Bingo Game Session Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,MasterCardNumber = ptg.MasterCardNumber        
  ,CardLevelName = ptg.CardLevelName        
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Regular' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)        
  JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)          
         
 --        
 -- Update records for Bingo Custom Game Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,DisplayGameNo = sgp.DisplayGameNo        
  ,DisplayPartNo = sgp.DisplayPartNo        
  ,GCName = sgp.GCName        
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Custom' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)        
  JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)        
  JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)        
 --        
 -- Update records for Bingo Game Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,DisplayGameNo = sgp.DisplayGameNo        
  ,DisplayPartNo = sgp.DisplayPartNo        
  ,GCName = sgp.GCName         
  ,MasterCardNumber = ptg.MasterCardNumber        
  ,CardLevelName = ptg.CardLevelName        
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Regular' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)        
  JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)        
  JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)        
 --        
 -- Update records for Bingo Good Neighbor Game Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,DisplayGameNo = sgp.DisplayGameNo        
  ,DisplayPartNo = sgp.DisplayPartNo        
  ,GCName = sgp.GCName         
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Good Neighbor' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoGoodNeighbor ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)        
  JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)          
  JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)        
 --        
 -- Update records for Bingo Royalty Game Payouts        
 --        
 UPDATE @Results        
 SET  GamingSession = sp.GamingSession        
  ,DisplayGameNo = sgp.DisplayGameNo        
  ,DisplayPartNo = sgp.DisplayPartNo        
  ,GCName = sgp.GCName         
  ,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Royalty' ELSE 'Progressive' END        
 FROM @Results r        
  JOIN PayoutTransBingoRoyalty ptg ON (r.PayoutTransID = ptg.PayoutTransID)        
  JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)        
  JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)            
     JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)        
 --        
 -- Add in "Cash" information to payouts        
 --        
 UPDATE @Results        
 SET  CashAmount = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCash WHERE PayoutTransID = r.PayoutTransID)        
 FROM @Results r        
  JOIN PayoutTransDetailCash ptd ON (ptd.PayoutTransID = r.PayoutTransID)         
          
 --        
 -- Add in "Check" information to payouts        
 --        
 UPDATE @Results        
 SET  CheckAmount = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCheck WHERE PayoutTransID = r.PayoutTransID)        
  ,CheckNumber = ptd.CheckNumber        
  ,Payee = ptd.Payee        
 FROM @Results r        
  JOIN PayoutTransDetailCheck ptd ON (ptd.PayoutTransID = r.PayoutTransID)          
          
 --        
 -- Add in "Credit" information to payouts        
 --        
 UPDATE @Results        
 SET  CreditAmount = (SELECT SUM(ISNULL(Refundable, 0)) + SUM(ISNULL(NonRefundable, 0)) FROM PayoutTransDetailCredit WHERE PayoutTransID = r.PayoutTransID)        
 FROM @Results r        
  JOIN PayoutTransDetailCredit ptd ON (ptd.PayoutTransID = r.PayoutTransID)          
          
 --        
 -- Add in "Merchandise" information to payouts        
 --        
 UPDATE @Results        
 SET  MerchandiseAmount = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailMerchandise WHERE PayoutTransID = r.PayoutTransID)        
         ,PayoutTypeName = CASE WHEN IsPrimary = 1 THEN 'Inventory' ELSE r.PayoutTypeName END        
 FROM @Results r        
  JOIN PayoutTransDetailMerchandise ptd ON (ptd.PayoutTransID = r.PayoutTransID)            
        
 --        
 -- Add in "Other" information to payouts        
 --        
 UPDATE @Results        
 SET  OtherAmount = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailOther WHERE PayoutTransID = r.PayoutTransID)        
 FROM @Results r        
  JOIN PayoutTransDetailOther ptd ON (ptd.PayoutTransID = r.PayoutTransID)            
        
-- Add in the Ball Count
--
 UPDATE @Results
 Set BallCount = (Select Count(BallCalled) From GameBallsCalled gbc 	
					Where gbc.SessionGamesPlayedID = ptbg.SessionGamesPlayedID
					And gbc.CallStatus = 1 And gbc.IsActive = 1)
 From @Results r
 Join PayoutTransBingoGame ptbg on (ptbg.PayoutTransID = r.PayoutTransID)					


-- Add in the Last Ball Call

UPDATE @Results
Set LastBallCall = (Select Top 1(BallCalled) From GameBallsCalled gbc
					 Where gbc.SessionGamesPlayedID = ptbg.SessionGamesPlayedID
					And gbc.CallStatus = 1 And gbc.IsActive = 1
					Order By gbc.GameBallCalledID DESC)
From @Results r
 Join PayoutTransBingoGame ptbg on (ptbg.PayoutTransID = r.PayoutTransID)			   
	

	
	-- Return our resultset!        
    SELECT                  
   PlayerID         
  ,PayoutTransID  ,       
 CONVERT(VARCHAR(10),GamingDate,110) as GamingDate      
      --  ,GamingDate           
        ,GamingSession          
        ,case   
        when DisplayGameNo is null then 0  
        else DisplayGameNo  
        end as DisplayGameNo,         
        DisplayPartNo          
        ,GCName            
        ,StaffID           
        ,MasterCardNumber         
        ,CardLevelName          
        ,PayoutTypeName          
        ,ISNULL(CashAmount, 0) AS CashAmount        
        ,ISNULL(CheckAmount, 0) AS CheckAmount        
        ,ISNULL(CreditAmount, 0) AS CreditAmount        
        ,ISNULL(MerchandiseAmount, 0) AS MerchandiseAmount        
        ,ISNULL(OtherAmount, 0) AS OtherAmount        
        ,CheckNumber          
        ,PayoutTransNumber         
        ,VoidTransNumber         
        ,Payee            
        ,PlayerName            
        ,TransactionTypeID         
        ,TransactionType         
		,DTStamp
		,LastBallCall 
		,BallCount               
  --,    
  --case     
  --when DisplayPartNo IS null then 0    
  --else    
  --cast(DisplayPartNo as int)  end  as x      
 into #a      
 FROM @Results        
 WHERE (@Session IS NULL OR @Session = GamingSession)        
 order by GamingDate, GamingSession, DisplayGameNo, DisplayPartNo, DTStamp;        
        
   

   
      ---------------------------  
      --4/26/2012 Karlo Camacho  
select GamingDate, Gamingsession into #b from #a group by GamingDate, GamingSession order by GamingDate asc  
           
 
           
select GamingDate, GamingSession, DisplayGameNo, cast(DisplayPartNo as NVARCHAR(50)) DisplayPartNo into #c from #a   
group by GamingDate, GamingSession, DisplayGameNo,DisplayPartNo  
  

  
 select GamingDate, GamingSession, DisplayGameNo  into #e from #a  
 group by GamingDate, GamingSession, DisplayGameNo  
  
select a.*,b.[Total Session], c.[Total Game], d.[Total Part],e.[Total Game2],f.[Total Game3]    from #a a join (  
select GamingDate, GamingSession ,COUNT(GamingSession) as [Total Game]  from #a   
group by GamingDate, GamingSession ) c on c.GamingDate = a.GamingDate and c.GamingSession = a.GamingSession --ok  
join (select GamingDate, COUNT(GamingDate) as [Total Session] from #b group by GamingDate) b   
on b.GamingDate = a.GamingDate   
left join (   
    select GamingDate, GamingSession, DisplayGameNo, COUNT(DisplayGameNo) as [Total Part]  from #c  
    group by  GamingDate, GamingSession, DisplayGameNo) d   
    on d.GamingDate = a.GamingDate  
    and d.GamingSession = a.GamingSession   
    and d.DisplayGameNo = a.DisplayGameNo    
    left join ( select GamingDate, GamingSession, DisplayGameNo, count(isnull(DisplayGameNo,0)) as [Total Game2]  from #a  
      group by  DisplayGameNo,GamingDate, GamingSession) e on   
      e.GamingDate = a.GamingDate  
      and e.GamingSession = a.GamingSession  
      and e.DisplayGameNo = a.DisplayGameNo  
    
   left join (  select GamingDate, GamingSession, count(GamingSession)as [Total Game3]  
 from #e  
 group by GamingDate, GamingSession) f  
on f.GamingDate = a.GamingDate  
and f.GamingSession = a.GamingSession  
--where a.GamingDate in ('05-25-2011','05-26-2011')  
     order by a.GamingDate desc  
       
     --247  
  
--select * from #e   
-- where GamingDate in ('05-26-2011')  
--  group by GamingDate, GamingSession, DisplayGameNo  
  
-- select GamingDate, GamingSession/*, count(GamingSession) as [Total Game3]*/ from #e   
-- where GamingDate in ('05-25-2011','05-26-2011')  
-- group by GamingDate, GamingSession  
   
  
   
 --select GamingDate, GamingSession, count(GamingSession)  
 --from #e  
 --group by GamingDate, GamingSession  
   
 --drop table #e  
  
      
  
  
      
    drop table #a  
    drop table #b   
    drop table #c   
    drop table #e  
    SET NOCOUNT OFF;      
    END;    
  
  



GO

