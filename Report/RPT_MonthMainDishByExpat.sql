USE [FBM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].RPT_MonthMainDishByExpat 
	@reportDate DATETIME
	,@DepartmentID VARCHAR(100) = NULL
	,@EmployeeTypeID VARCHAR(100) = NULL
	,@TeamID VARCHAR(100) = NULL
	,@WorkDay BIT = NULL--NULL - Show all; 1 - Work day; 0 - Off day
	,@Groupby INT = 0
	,@isDebug BIT = 0
	,@IsLocal INT = 0--NULL - Show all; 1 - Local; 0 - Expat
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

	IF OBJECT_ID('tempdb..#Employee') IS NOT NULL
	BEGIN
		DROP TABLE #Employee
	END

	CREATE TABLE #Employee (SysID INT)

	DECLARE @SQL NVARCHAR(MAX)

	SELECT @SQL = 'INSERT INTO #Employee(SysID) 
				SELECT ee.[SysID]
				FROM [dbo].[Employee] ee WITH (NOLOCK) ' + CASE 
			WHEN ISNULL(@DepartmentID, '') <> '' THEN CHAR(13) + ' INNER JOIN #Department tmpDe ON tmpDe.DepartmentID = ee.DepartmentID'
			ELSE ''
			END + CASE 
			WHEN ISNULL(@DepartmentID, '') <> ''
				AND ISNULL(@TeamID, '') <> '' THEN CHAR(13) + ' INNER JOIN #Team et ON et.DepartmentID = ee.DepartmentID
							AND et.EmpTeamID = ee.TeamID'
			ELSE ''
			END + CASE 
			WHEN ISNULL(@EmployeeTypeID, '') <> '' THEN + CHAR(13) + ' INNER JOIN #EmployeeType tmpEmpType ON tmpEmpType.[EmployeeTypeID] = ee.[EmpCategoryID] '
			ELSE ''
			END + CHAR(13) 
			+ CASE WHEN ISNULL(@IsLocal,-1)<>-1 THEN 
						CHAR(13) + 'WHERE ee.IsLocal = '+CONVERT(NVARCHAR(1),ISNULL(@IsLocal,1))--+' AND ee.isDeleted = 0 AND ee.Enabled = 1'
						ELSE '' END

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
		,DepartmentID SMALLINT
		,EmpTeamID INT
		,IsOffDay BIT
		)

	DECLARE @i INT

	SELECT @i = 1
		,@days = ''
		,@colsName = ''
		,@HeaderName=''
	SELECT @temptbl = ''
		,@updtbl = ''

	WHILE (@i <= @totalDays)
	BEGIN
		SET @colsName = @colsName + ',ISNULL([' + cast(@i AS VARCHAR(2)) + '],0) [' + cast(@i AS VARCHAR(2)) + ']'
		SET @days = @days + ',[' + cast(@i AS VARCHAR(2)) + ']'
		SET @HeaderName=@HeaderName +',[' + cast(@i AS VARCHAR(2)) + '] [D' + cast(@i AS VARCHAR(2)) + ']'
		SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [' + cast(@i AS VARCHAR(2)) + '] INT NULL' + CHAR(13)
		SET @i = @i + 1
	END

	SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [TotalQty] INT NULL' + CHAR(13)
	SET @temptbl = @temptbl + 'ALTER TABLE #tmpCalendar ADD [Amount] Money NULL' + CHAR(13)

	IF @isDebug = 1
		PRINT @temptbl

	EXECUTE sp_executesql @temptbl

	SELECT @query = 'INSERT  INTO #tmpCalendar (SysID,DepartmentID,EmpTeamID' + @days + ')' + CHAR(13)

	SELECT @query = @query + 'VALUES(NULL,NULL,NULL,'

	SELECT @totalDays = DAY(@ToDate)
		,@i = 1

	WHILE (@i <= @totalDays)
	BEGIN
		SET @query = @query + '' + CONVERT(VARCHAR(10), DATEPART(WEEKDAY, @fromDate)) + ','
		SET @fromDate = CONVERT(VARCHAR(10), CONVERT(DATETIME, @fromDate) + 1, 111) + ' 00:00:00'
		SET @i = @i + 1
	END

	SELECT @fromDate = cast(YEAR(@reportDate) AS VARCHAR(4)) + '/' + cast(MONTH(@reportDate) AS VARCHAR(2)) + '/01'

	SELECT @query = LEFT(@query, LEN(@query) - 1) + ')'

	IF @isDebug = 1
		PRINT @query

	EXECUTE sp_executesql @query

	SELECT @days = substring(@days, 2, len(@days) - 1)
		,@colsName = substring(@colsName, 2, len(@colsName) - 1)
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
		,e.[NickName]
		,day(DF.workdate) d
	INTO #Calendar
	FROM dbo.employee e WITH (NOLOCK)
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
		LEFT JOIN #CalendarDF DF WITH (NOLOCK)
		ON	--DF.[Enabled] = e.[Enabled]
			--AND DF.IsDeleted = e.IsDeleted
			1 = 1
	WHERE DF.WorkDate BETWEEN @fromDate AND @toDate

	IF OBJECT_ID('tempdb..#OrderQty') IS NOT NULL
	BEGIN
		DROP TABLE #OrderQty
	END

	CREATE TABLE #OrderQty (
		WorkDate DATE
		,MealID SMALLINT
		,SysID INT
		,IsOffDay BIT
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
		,IsOffDay
		,EmpMenuID
		,PricePerMeal
		,PricePerDay
		,Qty
		)
	SELECT ord.OnDate
		,ord.MealID
		,ordd.SysId
		,CASE 
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (1, 3) THEN 1
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (2)
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			WHEN ec.[isOffday] = 1
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			ELSE 0
			END IsOffDay
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(ordd.[QtyVeg], 0)) + SUM(ISNULL(ordd.[QtyNonVeg], 0)) Qty
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].[OrderDetail] ordd WITH (NOLOCK)
		ON ord.OrderID = ordd.OrderID
			AND ordd.IsDeleted = 0
			AND ordd.IsCancel = 0
		INNER JOIN dbo.employee e WITH (NOLOCK)
		ON ordd.SysId = e.SysID
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
		LEFT JOIN [dbo].[EmpCalendar] ec WITH (NOLOCK)
		ON ord.OnDate = ec.WorkDate
			AND e.[EmpId] = ec.[EmpId]
			AND e.[DepartmentID] = ec.[DepartmentID]
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
		,CASE 
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (1, 3) THEN 1
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (2)
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			WHEN ec.[isOffday] = 1
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			ELSE 0
			END
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	INSERT INTO #OrderQty (
		WorkDate
		,MealID
		,SysID
		,IsOffDay
		,EmpMenuID
		,PricePerMeal
		,PricePerDay
		,Qty
		)
	SELECT ord.OnDate
		,ord.MealID
		,ordA.SysId
		,CASE 
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (1, 3) THEN 1
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (2)
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			WHEN ec.[isOffday] = 1
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			ELSE 0
			END IsOffDay
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay
		,SUM(ISNULL(CONVERT(INT, ordA.[Qty]), 0)) Qty
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].[OrderAlternative] ordA WITH (NOLOCK)
		ON ord.OrderID = ordA.OrderID
			AND ordA.IsDeleted = 0
			AND ordA.IsCancel = 0
		INNER JOIN dbo.employee e WITH (NOLOCK)
		ON ordA.SysId = e.SysID
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
		LEFT JOIN [dbo].[EmpCalendar] ec WITH (NOLOCK)
		ON ord.OnDate = ec.WorkDate
			AND e.[EmpId] = ec.[EmpId]
			AND e.[DepartmentID] = ec.[DepartmentID]
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
		,CASE 
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (1, 3) THEN 1
			WHEN ec.[IsHoliday] = 1
				AND ec.DepartmentID IN (2)
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			WHEN ec.[isOffday] = 1
				AND ISNULL(ec.ShiftId, 0) <> 0 THEN 1
			ELSE 0
			END
		,eMenu.EmpMenuID
		,eMenuHis.PricePerMeal
		,eMenuHis.PricePerDay

	UPDATE tmp
	SET tmp.Amount = tmp.Qty * tmp.PricePerMeal
	FROM #OrderQty tmp
		INNER JOIN dbo.Employee ee WITH (NOLOCK)
		ON tmp.SysID = ee.SysID

	SET @query = '
		INSERT INTO #tmpCalendar (IsOffDay,SysID,EmpID,DepartmentID,EmpTeamID,' + @days + ')
		SELECT IsOffDay,SysID,EmpID,DepartmentID,EmpTeamID,' + @colsName + ' FROM (
			SELECT 
				tmpOrd.IsOffDay,' 
				+ CASE WHEN @Groupby = 0 THEN 'tmp.SysID' ELSE 'NULL SysID' END + CHAR(13) 
				+ CASE WHEN @Groupby = 0 THEN ',tmp.EmpID' ELSE ',NULL EmpID' END + CHAR(13) 
				+ ',ee.DepartmentID
				,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END EmpTeamID
				,tmp.d
				,SUM(ISNULL(tmpOrd.[Qty],0)) [Qty]
			FROM #Calendar	tmp WITH(NOLOCK)
				INNER JOIN #OrderQty tmpOrd
					ON tmp.SysID = tmpOrd.SysID
						AND  tmp.d = DATEPART(DAY,tmpOrd.WorkDate)
				INNER JOIN dbo.Employee ee WITH(NOLOCK)
						ON tmp.SysID = ee.SysID'+ CHAR(13) 
			+CASE WHEN @WorkDay IS NULL THEN ''
					WHEN @WorkDay = 1 THEN ' WHERE tmpOrd.IsOffDay = 0'+ CHAR(13) 
					WHEN @WorkDay = 0 THEN ' WHERE tmpOrd.IsOffDay = 1'+ CHAR(13) 
				END
			+'GROUP BY tmpOrd.IsOffDay,' 
			+ CASE WHEN @Groupby = 0 THEN 'tmp.SysID,'ELSE ''END + CHAR(13) 
			+ CASE WHEN @Groupby = 0 THEN 'tmp.EmpID,'ELSE ''END + CHAR(13) 
			+ 'ee.DepartmentID
				,CASE WHEN ISNULL(ee.TeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END
				,tmp.d
		) ea
		PIVOT
		(
			SUM(Qty) FOR d IN (' + @days + ')' + ') AS pvt'

	IF @isDebug = 1
		PRINT @query

	EXECUTE sp_executesql @query

	SELECT SysID
		,IsOffDay
		,SUM(CASE WHEN WorkDay_IsMeal = 1 THEN Qty ELSE 1 END) Qty
		,SUM(Price * CASE WHEN WorkDay_IsMeal = 1 THEN Qty ELSE 1 END) Price
	INTO #OrderQtySUM
	FROM (
		SELECT tmpQty.WorkDate
			,tmpQty.SysID
			,tmpQty.IsOffDay
			,(CASE WHEN WorkDay_IsMeal = 1 THEN Qty ELSE 1 END) Qty
			,MAX(CASE 
					WHEN tmpQty.IsOffDay = 0 THEN CASE 
							WHEN WorkDay_IsMeal = 1 THEN tmpQty.PricePerMeal
							ELSE tmpQty.PricePerDay
							END
					ELSE CASE 
							WHEN OFFDay_IsMeal = 1 THEN tmpQty.PricePerMeal
							ELSE tmpQty.PricePerDay
							END
					END) Price
			,WorkDay_IsMeal
			,OFFDay_IsMeal
		FROM #OrderQty tmpQty
			INNER JOIN dbo.Employee ee WITH (NOLOCK)
			ON tmpQty.SysID = ee.SysID
			INNER JOIN dbo.EmpCategoryMeal empCatMeal WITH (NOLOCK)
			ON empCatMeal.EmpCategoryID = ee.EmpCategoryID
		GROUP BY tmpQty.WorkDate
			,tmpQty.SysID
			,tmpQty.IsOffDay
			,WorkDay_IsMeal
			,OFFDay_IsMeal
			,(CASE WHEN WorkDay_IsMeal = 1 THEN Qty ELSE 1 END)
		) tmp
	GROUP BY SysID
		,IsOffDay
	
	IF @isDebug = 1
	BEGIN
		SELECT * FROM #OrderQty
		SELECT * FROM #OrderQtySUM
		SELECT * FROM #tmpCalendar
	END
	IF @Groupby = 0
	BEGIN

		UPDATE tmp 
		SET tmp.[Amount] = tmpqty.Amount
			,tmp.[TotalQty] = tmpqty.[Qty]
		FROM #tmpCalendar tmp
			LEFT JOIN (
				SELECT tmpqty.SysID
					,tmpqty.IsOffDay
					,SUM(ISNULL(tmpqty.Price,0)) Amount
					,SUM(tmpqty.[Qty]) [Qty]
				FROM #OrderQtySUM tmpqty
				GROUP BY tmpqty.SysID
					,tmpqty.IsOffDay
				) tmpqty
				ON tmp.SysID = tmpqty.SysID 
				AND tmp.IsOffDay = tmpqty.IsOffDay
		WHERE tmp.DepartmentID IS NOT NULL
	END


	ELSE IF @Groupby = 1
	BEGIN
		UPDATE tmp
		SET tmp.[TotalQty] = tmp1.[TotalQty]
			,tmp.[Amount] = tmp1.[Amount]  
		FROM #tmpCalendar tmp
			INNER JOIN (
			SELECT  tmp.DepartmentID
					--,CASE WHEN ISNULL(tmp.EmpTeamID,-1)=-1 AND ee.EmpId >=99990 THEN ee.EmpId ELSE ISNULL(ee.TeamID,-1) END EmpTeamID
					,ISNULL(tmp.EmpTeamID,-1) EmpTeamID
					,tmp.IsOffDay
					,SUM(tmpqty.[Qty]) [TotalQty]
					,SUM(tmpqty.Price) [Amount]
			FROM #OrderQtySUM tmpqty
			INNER JOIN dbo.Employee ee WITH (NOLOCK)
				ON ee.SysID = tmpqty.SysID
			LEFT JOIN #tmpCalendar tmp
				ON tmp.DepartmentID = ee.DepartmentID
					AND (tmp.EmpTeamID = ee.TeamID OR  (tmp.EmpTeamID >=99990 AND tmp.EmpTeamID = ee.EmpId) ) 
					AND tmp.IsOffDay = tmpqty.IsOffDay
			GROUP BY tmp.DepartmentID
					,ISNULL(tmp.EmpTeamID,-1)
					,tmp.IsOffDay
			) tmp1 ON  tmp.DepartmentID = tmp1.DepartmentID
					AND ISNULL(tmp.EmpTeamID,-1)  = ISNULL(tmp1.EmpTeamID,-1)
					AND tmp.IsOffDay = tmp1.IsOffDay
		WHERE tmp.DepartmentID IS NOT NULL
	END	 
	 
	IF OBJECT_ID('tempdb..#OrderQtySUM') IS NOT NULL
	BEGIN
		DROP TABLE #OrderQtySUM
	END
			
	IF OBJECT_ID('tempdb..#OrderQty') IS NOT NULL
	BEGIN
		DROP TABLE #OrderQty
	END
		
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
		SELECT @query = 'SELECT tmpCal.IsOffDay
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
					' + @HeaderName + ',TotalQty,Amount
				FROM #tmpCalendar tmpCal
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
				ORDER BY  tmpCal.IsOffDay
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
		SELECT @query = 'SELECT 
					tmpCal.IsOffDay
					,d.[DepartmentID]
					,d.NAME [DepartmentName]
					,ISNULL(et.EmpTeamID,CASE WHEN ete.EmpId >=99990 THEN ete.EmpID ELSE -1 END) EmpTeamID
					,ISNULL(et.[Code],CASE WHEN ete.EmpId >=99990 THEN ete.Code ELSE '''' END) EmpTeamCode
					,ISNULL(et.[Name],CASE WHEN ete.EmpId >=99990 THEN ete.NickName ELSE '''' END) EmpTeamName,
					' + @HeaderName + ',TotalQty,Amount
				FROM #tmpCalendar tmpCal
					LEFT  JOIN [dbo].[Department] d WITH (NOLOCK) 
						ON tmpCal.DepartmentID = d.DepartmentID					
					LEFT JOIN [dbo].[EmpTeam] et WITH (NOLOCK) 
						ON tmpCal.DepartmentID = et.DepartmentID
						AND tmpCal.EmpTeamID = et.EmpTeamID
					LEFT  JOIN dbo.Employee ete WITH(NOLOCK)
						ON tmpCal.EmpTeamID = ete.EmpID
						AND tmpCal.DepartmentID = ete.DepartmentID
				ORDER BY  tmpCal.IsOffDay
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
