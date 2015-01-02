USE [FBM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].RPT_MonthMainDishByLocal
	@reportDate DATETIME
	,@DepartmentID VARCHAR(100) = NULL
	,@EmployeeTypeID VARCHAR(100) = NULL
	,@TeamID VARCHAR(100) = NULL
	,@MealID VARCHAR(100) = NULL
	,@Groupby INT=0
	,@isDebug BIT = 0
	,@IsLocal INT = 1--NULL - Show all; 1 - Local; 0 - Expat
AS
/*
Created: Tom.Vo@2014-11-1
Task: view employee meal by month
DB: [FBM]
Original: 

Revisions:    
Param's Explanation:
	@Groupby : 
			0: Employee
			1: Department
*/
BEGIN
	SET NOCOUNT ON

	SELECT @DepartmentID = ISNULL(@DepartmentID, '')
		,@EmployeeTypeID = ISNULL(@EmployeeTypeID, '')
		,@TeamID = ISNULL(@TeamID, '')
		,@MealID = ISNULL(@MealID, '')

	IF OBJECT_ID('tempdb..#Department') IS NOT NULL
	BEGIN
		DROP TABLE #Department
	END
	
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

	CREATE TABLE #Team (
		DepartmentID SMALLINT
		,EmpTeamID SMALLINT
		)

	IF ISNULL(@DepartmentID, '') <> ''
		AND ISNULL(@TeamID, '') <> ''
	BEGIN
		INSERT INTO #Team (
			DepartmentID
			,EmpTeamID
			)
		SELECT et.DepartmentID
			,et.EmpTeamID
		FROM fnc_strSplit(@TeamID, ',') fnc
			INNER JOIN [dbo].[EmpTeam] et WITH (NOLOCK)
			ON fnc.val = et.EmpTeamID
			INNER JOIN #Department tmp
			ON tmp.DepartmentID = et.DepartmentID
	END

	IF OBJECT_ID('tempdb..#EmployeeType') IS NOT NULL
	BEGIN
		DROP TABLE #EmployeeType
	END

	CREATE TABLE #EmployeeType (EmployeeTypeID SMALLINT)

	IF ISNULL(@EmployeeTypeID, '') <> ''
	BEGIN
		INSERT INTO #EmployeeType (EmployeeTypeID)
		SELECT val
		FROM fnc_strSplit(@EmployeeTypeID, ',')
	END

	IF OBJECT_ID('tempdb..#MealID') IS NOT NULL
	BEGIN
		DROP TABLE #MealID
	END

	CREATE TABLE #MealID (MealID SMALLINT)

	IF ISNULL(@MealID, '') <> ''
	BEGIN
		INSERT INTO #MealID (MealID)
		SELECT val
		FROM fnc_strSplit(@MealID, ',')
	END
	ELSE
	BEGIN
		INSERT INTO #MealID (MealID)
		SELECT MealID FROM dbo.Meal WITH(NOLOCK)
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
				+ CASE WHEN ISNULL(@IsLocal,-1)<>-1 THEN 
						CHAR(13) + 'WHERE ee.IsLocal = '+CONVERT(NVARCHAR(1),ISNULL(@IsLocal,1))--+' AND ee.isDeleted = 0 AND ee.Enabled = 1'
						ELSE '' END
		
	IF @isDebug = 1
		PRINT @SQL
	EXECUTE sp_executesql @SQL

	DECLARE @Days VARCHAR(1000)
		,@colsName VARCHAR(2000)
		,@HeaderName VARCHAR(2000)
		,@totalDays INT
		,@fromDate DATETIME
		,@toDate DATETIME
		,@temptbl NVARCHAR(4000)
		,@updtbl NVARCHAR(4000)
		,@query NVARCHAR(4000)

	SET @fromDate = cast(YEAR(@reportDate) AS VARCHAR(4)) + '/' + cast(MONTH(@reportDate) AS VARCHAR(2)) + '/01'
	SET @ToDate = dateadd(d, - 1, dateadd(m, 1, @fromdate))
	SET @totalDays = DAY(@ToDate)

	CREATE TABLE #tmpCalendar (
		SysID INT
		,EmpID INT
		,MealID SMALLINT
		,DepartmentID SMALLINT
		,EmpTeamID INT
		)

	DECLARE @i INT

	SELECT @i = 1
		,@days = ''
		,@colsName=''
		,@HeaderName=''

	SELECT @temptbl = ''
		,@updtbl = ''

	WHILE (@i <= @totalDays)
	BEGIN
		SET @colsName = @colsName + ',ISNULL([' + cast(@i AS VARCHAR(2)) + '],0) [' + cast(@i AS VARCHAR(2)) + ']'
		SET @days=@days +',[' + cast(@i AS VARCHAR(2)) + ']'
		SET @HeaderName=@HeaderName +',[' + cast(@i AS VARCHAR(2)) + '] [D' + cast(@i AS VARCHAR(2)) + ']'
		SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [' + cast(@i AS VARCHAR(2)) + '] INT NULL' + CHAR(13)
		SET @updtbl=@updtbl+'+ISNULL([' + cast(@i AS VARCHAR(2)) + '],0)'
		SET @i = @i + 1
	END

	SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [TotalQty] INT NULL' + CHAR(13)
	SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [Amount] Money NULL' + CHAR(13)
		
	IF @isDebug = 1
		PRINT @temptbl

	EXECUTE sp_executesql @temptbl

	SELECT @query='INSERT  INTO #tmpCalendar (SysID,MealID,DepartmentID,EmpTeamID' + @days + ')' + CHAR(13)
	SELECT @query=@query + 'VALUES(NULL,NULL,NULL,NULL,'
	
	SELECT @totalDays = DAY(@ToDate),@i = 1
	while (@i<=@totalDays)
	begin
		SET @query = @query + '' + CONVERT(VARCHAR(10),DATEPART(WEEKDAY,@fromDate)) + ','
		SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		set @i=@i+1	
	end 
	
	SELECT @fromDate = cast(YEAR(@reportDate) AS VARCHAR(4)) + '/' + cast(MONTH(@reportDate) AS VARCHAR(2)) + '/01'
	
	SELECT @query=LEFT(@query,LEN(@query)-1) + ')'

	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query 

	SELECT @days = substring(@days, 2, len(@days) - 1)
			,@colsName = substring(@colsName, 2, len(@colsName) - 1)
			,@updtbl = RIGHT(@updtbl,LEN(@updtbl)-1)
			,@HeaderName= substring(@HeaderName, 2, len(@HeaderName) - 1)
	CREATE TABLE #CalendarDF (
		WorkDate DATE
		,[Enabled] BIT
		,IsDeleted BIT
		)

	WHILE (@fromDate <= @toDate)
	BEGIN
		INSERT INTO #CalendarDF (
			WorkDate
			,[Enabled]
			,IsDeleted
			)
		VALUES (
			@fromDate
			,1
			,0
			)

		SET @fromDate = CONVERT(VARCHAR(10), CONVERT(DATETIME, @fromDate) + 1, 111) + ' 00:00:00'
	END

	SELECT @fromDate = cast(YEAR(@reportDate) AS VARCHAR(4)) + '/' + cast(MONTH(@reportDate) AS VARCHAR(2)) + '/01'

	SELECT e.[SysID]
		,e.[EmpId]
		,e.[DepartmentID]
		,day(DF.workdate) d
	INTO #Calendar
	FROM dbo.employee e WITH (NOLOCK)
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID		
		LEFT JOIN #CalendarDF DF WITH (NOLOCK)
		--ON DF.[Enabled] = e.[Enabled]
		--	AND DF.IsDeleted = e.IsDeleted
		ON 1 = 1
	WHERE DF.WorkDate BETWEEN @fromDate AND @toDate

	IF OBJECT_ID('tempdb..#OrderQty') IS NOT NULL
	BEGIN
		DROP TABLE #OrderQty
	END

	CREATE TABLE #OrderQty (
		WorkDate DATE
		,MealID SMALLINT
		,SysID INT
		,EmpMenuID INT
		,PricePerMeal MONEY
		,PricePerDay MONEY
		,Qty INT
		,Amount MONEY
		)

	INSERT INTO #OrderQty (
		WorkDate
		,MealID
		,SysID
		,EmpMenuID
		,PricePerMeal
		,PricePerDay
		,Qty
		)
	SELECT ord.OnDate
		,ord.MealID
		,ordd.SysId
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(ordd.[QtyVeg], 0)) + SUM(ISNULL(ordd.[QtyNonVeg], 0)) Qty
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN #MealID tmpMeal 
			ON ord.MealID = tmpMeal.MealID
		INNER JOIN [dbo].[OrderDetail] ordd WITH (NOLOCK)
		ON ord.OrderID = ordd.OrderID
			AND ordd.IsDeleted = 0
			AND ordd.IsCancel = 0
		INNER JOIN dbo.employee e WITH (NOLOCK)
		ON ordd.SysId = e.SysID
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
		LEFT JOIN dbo.[FoodMenu] fm WITH (NOLOCK)
		ON fm.MenuID = ordd.MenuID
		LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
		ON erf.WorkDate = ord.OnDate
			AND erf.MealID = ord.MealID
			AND erf.SysId = e.SysId
		LEFT JOIN dbo.[EmpMeal] em WITH (NOLOCK)
		ON fm.EmpMenuID = em.EmpMenuID
			AND em.MealID = ord.MealID
		LEFT JOIN dbo.[EmpMenu] eMenu WITH (NOLOCK)
		ON em.EmpMenuID = eMenu.EmpMenuID
			AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
		LEFT JOIN [dbo].[EmpMenuHis] eMenuHis WITH (NOLOCK)
		ON eMenu.EmpMenuID = eMenuHis.EmpMenuID
			AND ord.OnDate BETWEEN eMenuHis.EffectedDateBegin AND ISNULL(eMenuHis.EffectedDateEnd, GETDATE() + 1)
	WHERE ord.OnDate BETWEEN @fromDate AND @toDate
		AND [CurrentStatusID] IN (4, 5)
	GROUP BY ord.OnDate
		,ord.MealID
		,ordd.SysId
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	INSERT INTO #OrderQty (
		WorkDate
		,MealID
		,SysID
		,EmpMenuID
		,PricePerMeal
		,PricePerDay
		,Qty
		)
	SELECT ord.OnDate
		,ord.MealID
		,ordA.SysId
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(CONVERT(INT, ordA.[Qty]), 0)) Qty
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN #MealID tmpMeal 
			ON ord.MealID = tmpMeal.MealID
		INNER JOIN [dbo].[OrderAlternative] ordA WITH (NOLOCK)
		ON ord.OrderID = ordA.OrderID
			AND ordA.IsDeleted = 0
			AND ordA.IsCancel = 0
		INNER JOIN dbo.employee e WITH (NOLOCK)
		ON ordA.SysId = e.SysID
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
		LEFT JOIN dbo.[FoodMenu] fm WITH (NOLOCK)
		ON fm.MenuID = ordA.MenuID
		LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
		ON erf.WorkDate = ord.OnDate
			AND erf.MealID = ord.MealID
			AND erf.SysId = e.SysId
		LEFT JOIN dbo.[EmpMeal] em WITH (NOLOCK)
		ON fm.EmpMenuID = em.EmpMenuID
			AND em.MealID = ord.MealID
		LEFT JOIN dbo.[EmpMenu] eMenu WITH (NOLOCK)
		ON em.EmpMenuID = eMenu.EmpMenuID
			AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
		LEFT JOIN [dbo].[EmpMenuHis] eMenuHis WITH (NOLOCK)
		ON eMenu.EmpMenuID = eMenuHis.EmpMenuID
			AND ord.OnDate BETWEEN eMenuHis.EffectedDateBegin AND ISNULL(eMenuHis.EffectedDateEnd, GETDATE() + 1)
	WHERE ord.OnDate BETWEEN @fromDate AND @toDate
		AND [CurrentStatusID] IN (4, 5)
	GROUP BY ord.OnDate
		,ord.MealID
		,ordA.SysId
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	
	IF @isDebug = 1 SELECT * FROM #OrderQty

	UPDATE tmp
	SET tmp.Amount = tmp.Qty * tmp.PricePerMeal
	FROM #OrderQty tmp
		INNER JOIN dbo.Employee ee WITH (NOLOCK)
		ON tmp.SysID = ee.SysID
	
	SET @query = '
		INSERT INTO #tmpCalendar (SysID,EmpID,DepartmentID,EmpTeamID,MealID,' + @days + ')
		SELECT SysID,EmpID,DepartmentID,EmpTeamID,MealID,' + @colsName + ' FROM (
			SELECT '
				+ CASE WHEN @Groupby = 0 THEN 'tmp.SysID' ELSE 'NULL SysID' END
				+ CASE WHEN @Groupby = 0 THEN ',tmp.EmpID' ELSE ',NULL EmpID' END
				+CHAR(13)+',ee.DepartmentID
				,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END EmpTeamID
				,tmpOrd.MealID
				--,ISNULL(tmpOrd.IsOffDay,0) IsOffDay
				,tmp.d
				,SUM(ISNULL(tmpOrd.[Qty],0)) [Qty]
			FROM #Calendar	tmp WITH(NOLOCK)
				INNER JOIN #OrderQty tmpOrd
					ON tmp.SysID = tmpOrd.SysID
						AND  tmp.d = DATEPART(DAY,tmpOrd.WorkDate)
				INNER JOIN dbo.Employee ee WITH(NOLOCK)
						ON tmp.SysID = ee.SysID
			GROUP BY '
				+ CASE WHEN @Groupby = 0 THEN 'tmp.SysID,' ELSE '' END
				+ CASE WHEN @Groupby = 0 THEN 'tmp.EmpID,' ELSE '' END
				+CHAR(13)+'ee.DepartmentID
				,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END
				,tmpOrd.MealID
				,tmp.d
		) ea
		PIVOT
		(
			SUM(Qty) FOR d IN (' + @days + ')' + ') AS pvt'
 
	IF @isDebug = 1
		PRINT @query

	EXECUTE sp_executesql @query

	SET @query = 'UPDATE tmp '
				+ CHAR(13) + 'SET [TotalQty] = ' + @updtbl
				+ CHAR(13) + 'FROM #tmpCalendar tmp '
				+ CHAR(13) + 'WHERE tmp.DepartmentID IS NOT NULL'
 
	IF @isDebug = 1
		PRINT @query

	EXECUTE sp_executesql @query
	
	IF @Groupby = 0
	BEGIN
		UPDATE tmp 
		SET tmp.[Amount] = tmpqty.Amount
		FROM #tmpCalendar tmp
			LEFT JOIN (
				SELECT tmpqty.SysID				
					,tmpqty.MealID
					,SUM(tmpqty.[Qty]*ISNULL(tmpqty.PricePerMeal,0)) Amount
				FROM #OrderQty tmpqty
				GROUP BY 	 tmpqty.SysID
						,tmpqty.MealID
				) tmpqty
				ON tmp.SysID = tmpqty.SysID AND tmp.MealID = tmpqty.MealID
		WHERE tmp.DepartmentID IS NOT NULL
	END
	ELSE IF @Groupby = 1
	BEGIN
		UPDATE tmp 
		SET tmp.[Amount] = tmpqty.Amount
		FROM  (
				SELECT ee.DepartmentID
					,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END TeamID
					,tmpqty.MealID
					,SUM(tmpqty.[Qty]*ISNULL(tmpqty.PricePerMeal,0)) Amount
				FROM #OrderQty tmpqty
					INNER JOIN dbo.Employee ee WITH(NOLOCK)
						ON ee.SysID = tmpqty.SysID
				GROUP BY 	ee.DepartmentID
					,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END 
					,tmpqty.MealID
				) tmpqty
			LEFT JOIN #tmpCalendar tmp
				ON tmp.DepartmentID = tmpqty.DepartmentID
				AND ISNULL(tmp.EmpTeamID,-1)  = ISNULL(tmpqty.TeamID,-1)
				AND tmp.MealID = tmpqty.MealID
			WHERE tmp.DepartmentID IS NOT NULL
	END

	IF @isDebug = 1 SELECT * FROM #Employee
	IF @isDebug = 1 SELECT * FROM #OrderQty

	DROP TABLE #OrderQty		
	
	IF OBJECT_ID('tempdb..#Department') IS NOT NULL
	BEGIN
		DROP TABLE #Department
	END

	IF OBJECT_ID('tempdb..#Team') IS NOT NULL
	BEGIN
		DROP TABLE #Team
	END

	IF OBJECT_ID('tempdb..#EmployeeType') IS NOT NULL
	BEGIN
		DROP TABLE #EmployeeType
	END

	IF OBJECT_ID('tempdb..#Employee') IS NOT NULL
	BEGIN
		DROP TABLE #Employee
	END

	IF @Groupby = 0
	BEGIN
		SELECT @query = 
				'SELECT 
					me.[MealID]
					,me.ENGName MealEngName
					,me.VNMName MealVNMName

					,empCat.[EmpCategoryID] EmployeeTypeID
					,empCat.[CategoryName] EmployeeTypeName

					,d.[DepartmentID]
					,d.NAME [DepartmentName]
					,ISNULL(et.EmpTeamID,CASE WHEN ete.EmpId >=99990 THEN ete.EmpID ELSE -1 END) EmpTeamID
					,ISNULL(et.[Code],CASE WHEN ete.EmpId >=99990 THEN ete.Code ELSE '''' END) EmpTeamCode
					,ISNULL(et.[Name],CASE WHEN ete.EmpId >=99990 THEN ete.NickName ELSE '''' END) EmpTeamName

					,ee.[DomainUsername]
					,ee.[Code]
					,ee.[FullName]
					,ee.[NickName]
					,ee.[SysID],
					'
					+ @HeaderName
					+',TotalQty,Amount
				FROM #tmpCalendar tmpCal
					LEFT JOIN dbo.Meal me WITH(NOLOCK)
						ON tmpCal.MealID = me.MealID
					LEFT  JOIN dbo.Employee ee WITH(NOLOCK)
						ON tmpCal.SysID = ee.SysID
					LEFT  JOIN dbo.EmpCategory empCat WITH(NOLOCK)
						ON ee.EmpCategoryID = empCat.EmpCategoryID
					LEFT  JOIN [dbo].[Department] d WITH (NOLOCK) 
						ON ee.DepartmentID = d.DepartmentID
					LEFT JOIN [dbo].[EmpTeam] et WITH (NOLOCK) 
						ON ee.DepartmentID = et.DepartmentID
						AND ee.TeamID = et.EmpTeamID
					LEFT  JOIN dbo.Employee ete WITH(NOLOCK)
						ON tmpCal.EmpID = ete.EmpID
						AND tmpCal.DepartmentID = ete.DepartmentID
				ORDER BY me.[MealID]					
					,d.[DepartmentID]
					,ISNULL(et.[Name],CASE WHEN ete.EmpId >=99990 THEN ete.NickName ELSE '''' END) 
					,empCat.[EmpCategoryID]
					,ee.[NickName]
				'
		IF @isDebug = 1
			PRINT @query
	
		EXECUTE sp_executesql @query

	END
	ELSE IF @Groupby = 1
	BEGIN
		SELECT @query = 
				'SELECT 
					me.[MealID]
					,me.ENGName MealEngName
					,me.VNMName MealVNMName
					
					,d.[DepartmentID]
					,d.NAME [DepartmentName]
					,ISNULL(et.EmpTeamID,CASE WHEN ete.EmpId >=99990 THEN ete.EmpID ELSE -1 END) EmpTeamID
					,ISNULL(et.[Code],CASE WHEN ete.EmpId >=99990 THEN ete.Code ELSE '''' END) EmpTeamCode
					,ISNULL(et.[Name],CASE WHEN ete.EmpId >=99990 THEN ete.NickName ELSE '''' END) EmpTeamName,
					'
					+ @HeaderName
					+',TotalQty,Amount
				FROM #tmpCalendar tmpCal
					LEFT  JOIN dbo.Meal me WITH(NOLOCK)
						ON tmpCal.MealID = me.MealID
					LEFT  JOIN [dbo].[Department] d WITH (NOLOCK) 
						ON tmpCal.DepartmentID = d.DepartmentID					
					LEFT JOIN [dbo].[EmpTeam] et WITH (NOLOCK) 
						ON tmpCal.DepartmentID = et.DepartmentID
						AND tmpCal.EmpTeamID = et.EmpTeamID
					LEFT  JOIN dbo.Employee ete WITH(NOLOCK)
						ON tmpCal.EmpTeamID = ete.EmpID
						AND tmpCal.DepartmentID = ete.DepartmentID
				ORDER BY me.[MealID]
					,d.[DepartmentID]
					,ISNULL(et.[Name],CASE WHEN ete.EmpId >=99990 THEN ete.NickName ELSE '''' END) 
				'
		IF @isDebug = 1
			PRINT @query
	
		EXECUTE sp_executesql @query

	END
	IF @isDebug = 1
	BEGIN
		SELECT *
		FROM #tmpCalendar
		ORDER BY MealID
	END
	
	IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL
	BEGIN
		DROP TABLE #Calendar
	END

	IF OBJECT_ID('tempdb..#CalendarDF') IS NOT NULL
	BEGIN
		DROP TABLE #CalendarDF
	END 

	IF OBJECT_ID('tempdb..#tmpCalendar') IS NOT NULL
	BEGIN
		DROP TABLE #tmpCalendar
	END
END
