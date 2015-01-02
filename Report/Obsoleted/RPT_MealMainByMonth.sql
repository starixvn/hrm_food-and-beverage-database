USE [FBM]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Rpt_MealMainByMonth]
	@reportDate datetime,
	@DepartmentID VARCHAR(100)=NULL,
	@EmployeeTypeID VARCHAR(100)=NULL,
	@TeamID VARCHAR(100)=NULL,
	@MealID VARCHAR(100)=NULL,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2014-11-1
Task: view employee meal by month
DB: [FBM]
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
 
	SELECT @DepartmentID = ISNULL(@DepartmentID,'') 
		,@EmployeeTypeID = ISNULL(@EmployeeTypeID,'') 
		,@TeamID = ISNULL(@TeamID,'') 
		,@MealID = ISNULL(@MealID,'')  
	
	DECLARE @Restrict BIT
	SET @Restrict = dbo.func_GetRestrictOtherCompany() 

	IF OBJECT_ID('tempdb..#Department') IS NOT NULL
	BEGIN
		DROP TABLE #Department
	END

	CREATE TABLE #Department (DepartmentID SMALLINT)

	IF ISNULL(@DepartmentID,'')=''
	BEGIN
		INSERT INTO #Department(DepartmentID)
		SELECT DepartmentID FROM [dbo].[Department] dp WITH(NOLOCK) 
		WHERE (@Restrict = 0 OR dp.HeadDepartment = 1)

		SELECT @DepartmentID='1'
	END
	ELSE IF ISNULL(@DepartmentID, '') <> ''
	BEGIN
		INSERT INTO #Department (DepartmentID)
		SELECT val
		FROM fnc_strSplit(@DepartmentID, ',')fnc
		INNER JOIN [dbo].[Department] dp WITH(NOLOCK) 
			ON fnc.val = dp.DepartmentID
		WHERE (@Restrict = 0 OR dp.HeadDepartment = 1)
	END

	IF OBJECT_ID('tempdb..#Team') IS NOT NULL
		BEGIN
			DROP TABLE #Team
		END 
		
	CREATE TABLE #Team (DepartmentID SMALLINT,EmpTeamID SMALLINT)

	IF ISNULL(@DepartmentID,'')<>'' AND ISNULL(@TeamID,'')<>''
	BEGIN
		INSERT INTO #Team (DepartmentID,EmpTeamID)
		SELECT et.DepartmentID,et.EmpTeamID 
		FROM fnc_strSplit (@TeamID, ',') fnc
			INNER JOIN [dbo].[EmpTeam] et WITH (NOLOCK) ON fnc.val = et.EmpTeamID
			INNER JOIN #Department tmp ON tmp.DepartmentID = et.DepartmentID
	END

	IF OBJECT_ID('tempdb..#EmployeeType') IS NOT NULL
		BEGIN
			DROP TABLE #EmployeeType
		END 

	CREATE TABLE #EmployeeType (EmployeeTypeID SMALLINT)

	IF ISNULL(@EmployeeTypeID,'')<>''
	BEGIN
		INSERT INTO #EmployeeType (EmployeeTypeID)
		SELECT val FROM fnc_strSplit (@EmployeeTypeID, ',')
	END	

	IF OBJECT_ID('tempdb..#MealID') IS NOT NULL
		BEGIN
			DROP TABLE #MealID
		END 

	CREATE TABLE #MealID (MealID SMALLINT)

	IF ISNULL(@MealID,'')<>''
	BEGIN
		INSERT INTO #MealID (MealID)
		SELECT val FROM fnc_strSplit (@MealID, ',')
	END
	
	IF OBJECT_ID('tempdb..#Employee') IS NOT NULL
		BEGIN
			DROP TABLE #Employee
		END 
		
	CREATE TABLE #Employee (SysID INT)
	
	DECLARE @SQL NVARCHAR(MAX)
	
	SELECT @SQL ='INSERT INTO #Employee(SysID) 
				SELECT ee.[SysID]
				FROM [dbo].[Employee] ee WITH (NOLOCK) '
				+ CASE WHEN ISNULL(@DepartmentID,'')<>'' THEN 
						CHAR(13) +' INNER JOIN #Department tmpDe ON tmpDe.DepartmentID = ee.DepartmentID' 
						ELSE '' END
				+ CASE WHEN ISNULL(@DepartmentID,'')<>'' AND ISNULL(@TeamID,'')<>'' THEN 
						CHAR(13) +' INNER JOIN #Team et ON et.DepartmentID = ee.DepartmentID
							AND et.EmpTeamID = ee.TeamID'
						ELSE '' END
				+ CASE WHEN ISNULL(@EmployeeTypeID,'')<>'' THEN 
						+CHAR(13) +' INNER JOIN #EmployeeType tmpEmpType ON tmpEmpType.[EmployeeTypeID] = ee.[EmpCategoryID] '
						ELSE '' END

	EXECUTE sp_executesql @SQL
	 
	DECLARE @Days varchar(1000), @cols varchar(2000), @totalDays int, 
			@fromDate datetime, @toDate datetime,
			@temptbl nvarchar(4000),@updtbl nvarchar(4000)

	-- first day of month
	set @fromDate= cast(YEAR(@reportDate) as varchar(4)) + '/' + cast(MONTH(@reportDate) as varchar(2)) + '/01'

	-- last day of month
	set @ToDate = dateadd(d,-1, dateadd(m,1,@fromdate))

	set @totalDays = DAY(@ToDate)

	CREATE TABLE #tmpCalendar(SysID INT,IsOffDay BIT)

	declare @i int
	select  @i=1, @days=''
	select @temptbl='',@updtbl=''
	while (@i<=@totalDays)
	begin
		set @days= @days + ',[' + cast(@i as varchar(2)) + ']'
		set @temptbl=@temptbl+'ALTER TABLE #tmpCalendar ADD [' + cast(@i as varchar(2)) + '] NVARCHAR(100) NULL' +CHAR(13)
		set @i=@i+1	
	end

	IF @isDebug = 1 print @temptbl
	EXECUTE sp_executesql @temptbl

	select  @days=substring(@days,2, len(@days)-1)
	
	CREATE TABLE #CalendarDF(WorkDate DATE,[Enabled] BIT,IsDeleted BIT)

	WHILE (@fromDate<=@toDate) 
		BEGIN
			INSERT INTO #CalendarDF(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END
	SELECT @fromDate = cast(YEAR(@reportDate) as varchar(4)) + '/' + cast(MONTH(@reportDate) as varchar(2)) + '/01'
	 
	SELECT  e.[SysID]
		,e.[EmpId]
		,e.[DepartmentID]
		--,dep.NAME [DepartmentName]
		--,e.TeamID
		--,Team.[Code] EmpTeamCode
		--,Team.[Name] EmpTeamName
		--,e.[DomainUsername]
		--,e.[Code]
		--,e.[FullName]
		--,e.[NickName]
		,day(DF.workdate) d
			
	INTO #Calendar
	FROM dbo.employee e WITH(NOLOCK)
		INNER JOIN #Employee tmpEmp ON e.SysID = tmpEmp.SysID
		INNER JOIN dbo.Department dep ON e.DepartmentID = dep.DepartmentID
		INNER JOIN dbo.EmpTeam Team ON e.DepartmentID = Team.DepartmentID AND e.TeamID = Team.EmpTeamId
		LEFT JOIN #CalendarDF DF  WITH (NOLOCK) on DF.[Enabled]= e.[Enabled] AND DF.IsDeleted= e.IsDeleted
	WHERE DF.WorkDate between @fromDate and @toDate

	IF OBJECT_ID('tempdb..#OrderQty') IS NOT NULL
		BEGIN
			DROP TABLE #OrderQty
		END

	CREATE TABLE #OrderQty (WorkDate DATE
			,MealID SMALLINT
			,SysID INT
			,IsOffDay BIT
			,EmpMenuID INT
			,PricePerMeal	MONEY
			,PricePerDay 	MONEY
			,Qty INT)

	INSERT INTO #OrderQty (WorkDate,MealID,SysID,IsOffDay,EmpMenuID,PricePerMeal,PricePerDay,Qty)
	SELECT ord.OnDate
		,ord.MealID
		,ordd.SysId
		,CASE WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (1,3) THEN 1
					WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (2)  AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					WHEN ec.[isOffday] = 1 AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					ELSE 0
					END IsOffDay
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(ordd.[QtyVeg],0)) + SUM(ISNULL(ordd.[QtyNonVeg],0)) Qty
	FROM [dbo].[Order] ord WITH(NOLOCK)
	INNER JOIN [dbo].[OrderDetail] ordd WITH(NOLOCK)
		ON ord.OrderID = ordd.OrderID AND ordd.IsDeleted = 0 AND ordd.IsCancel = 0
	INNER JOIN dbo.employee e WITH(NOLOCK) 
		ON ordd.SysId = e.SysID
	INNER JOIN #Employee tmpEmp 
		ON e.SysID = tmpEmp.SysID
	LEFT JOIN [dbo].[EmpCalendar] ec WITH (NOLOCK)
					ON ord.OnDate = ec.WorkDate
						AND e.[EmpId] = ec.[EmpId]
						AND e.[DepartmentID] = ec.[DepartmentID]
	LEFT JOIN dbo.[FoodMenu] fm WITH (NOLOCK)
			ON fm.MenuID = ordd.MenuID	
	LEFT JOIN dbo.EmpRegisterFood erf WITH(NOLOCK)
		ON erf.WorkDate = ord.OnDate
			AND erf.MealID = ord.MealID
			AND erf.SysId = e.SysId
	LEFT JOIN dbo.[EmpMeal] em WITH(NOLOCK)
		ON fm.EmpMenuID = em.EmpMenuID 
		AND em.MealID = ord.MealID
	LEFT JOIN dbo.[EmpMenu] eMenu WITH(NOLOCK)
		ON em.EmpMenuID = eMenu.EmpMenuID 
			AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian,0)
	LEFT JOIN [dbo].[EmpMenuHis] eMenuHis WITH(NOLOCK)
		 ON eMenu.EmpMenuID = eMenuHis.EmpMenuID 
			AND ord.OnDate BETWEEN eMenuHis.EffectedDateBegin AND ISNULL(eMenuHis.EffectedDateEnd,GETDATE()+1)
	WHERE  ord.OnDate between @fromDate and @toDate
		AND [CurrentStatusID] IN (4,5)
	GROUP BY ord.OnDate
		,ord.MealID
		,ordd.SysId
		,CASE WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (1,3) THEN 1
					WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (2)  AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					WHEN ec.[isOffday] = 1 AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					ELSE 0
					END 
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	INSERT INTO #OrderQty (WorkDate,MealID,SysID,IsOffDay,EmpMenuID,PricePerMeal,PricePerDay,Qty)
	SELECT ord.OnDate
		,ord.MealID
		,ordA.SysId
		,CASE WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (1,3) THEN 1
					WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (2)  AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					WHEN ec.[isOffday] = 1 AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					ELSE 0
					END IsOffDay
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(CONVERT(INT,ordA.[Qty]),0)) Qty
	FROM [dbo].[Order] ord WITH(NOLOCK)
	INNER JOIN [dbo].[OrderAlternative] ordA WITH(NOLOCK)
		ON ord.OrderID = ordA.OrderID AND ordA.IsDeleted = 0 AND ordA.IsCancel = 0
	INNER JOIN dbo.employee e WITH(NOLOCK) 
		ON ordA.SysId = e.SysID
	INNER JOIN #Employee tmpEmp 
		ON e.SysID = tmpEmp.SysID
	INNER JOIN [dbo].[EmpMenuSub] emus WITH(NOLOCK)
			ON e.EmpCategoryID = emus.EmpCategoryID
				AND emus.IsActive = 1
	INNER JOIN [dbo].[EmpMeal] ems WITH(NOLOCK)
		ON ems.EmpMenuID = emus.EmpMenuID
			AND ems.IsActive = 1
			AND ems.MealID = ord.MealID
	LEFT JOIN dbo.EmpRegisterFood erf WITH(NOLOCK)
		ON erf.WorkDate = ord.OnDate
			AND erf.MealID = ord.MealID
			AND erf.SysId = e.SysId
	INNER JOIN dbo.EmpMenu eMenu WITH(NOLOCK)
		ON eMenu.EmpMenuID = ems.EmpMenuID
			AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian,0)
			AND eMenu.IsActive = 1
	LEFT JOIN [dbo].[EmpCalendar] ec WITH (NOLOCK)
					ON ord.OnDate = ec.WorkDate
						AND e.[EmpId] = ec.[EmpId]
						AND e.[DepartmentID] = ec.[DepartmentID]
	LEFT JOIN [dbo].[EmpMenuHis] eMenuHis WITH(NOLOCK)
		 ON eMenu.EmpMenuID = eMenuHis.EmpMenuID 
			AND ord.OnDate BETWEEN eMenuHis.EffectedDateBegin AND ISNULL(eMenuHis.EffectedDateEnd,GETDATE()+1)
	WHERE ord.OnDate between @fromDate and @toDate
		AND [CurrentStatusID] IN (4,5)
	GROUP BY  ord.OnDate
		,ord.MealID
		,ordA.SysId
		,CASE WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (1,3) THEN 1
					WHEN ec.[IsHoliday] = 1 AND ec.DepartmentID IN (2)  AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					WHEN ec.[isOffday] = 1 AND ISNULL(ec.ShiftId,0) <> 0 THEN 1
					ELSE 0
					END 
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	SELECT * FROM #OrderQty
	ORDER BY SYSID

	SELECT * FROM #Calendar

	Declare @query nvarchar(4000)		 

	SET @cols='SysID,IsOffDay,' +  @days
	SET @query = '
		INSERT INTO #tmpCalendar ('+@cols+')
		SELECT '+ @cols 
		+' FROM (
			SELECT tmp.SysID
				,ISNULL(tmpOrd.IsOffDay,0) IsOffDay
				,tmp.d
				,SUM(ISNULL(tmpOrd.[Qty],0)) [Qty]
			FROM #Calendar	tmp WITH(NOLOCK)
				LEFT JOIN #OrderQty tmpOrd
					ON tmp.SysID = tmpOrd.SysID
						AND  tmp.d = DATEPART(DAY,tmpOrd.WorkDate)
			GROUP BY tmp.SysID
				,ISNULL(tmpOrd.IsOffDay,0) 
				,tmp.d
		) ea
		PIVOT
		(
			SUM(Qty) FOR d IN (' + @days + ')' + 
		') AS pvt'

		
	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query
	 
	DROP TABLE #OrderQty

	SELECT * FROM #tmpCalendar 
	ORDER BY SysID
END