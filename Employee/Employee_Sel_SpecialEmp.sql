USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MenuBySysID]    Script Date: 10/27/2014 4:55:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Sel_SpecialEmp]
	 @SysID INT=NULL
	,@DepartmentID VARCHAR(100) = NULL
	,@EmployeeTypeID VARCHAR(100) = NULL
	,@Status BIT = NULL

AS
/*
Created: Tom.Vo@2014-8-25
Task: This function is used to select the special employees.
DB: FBM
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT @DepartmentID = ISNULL(@DepartmentID, '')
		,@EmployeeTypeID = ISNULL(@EmployeeTypeID, '')

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
	ELSE
		BEGIN
		INSERT INTO #EmployeeType (EmployeeTypeID)
		SELECT [EmpCategoryID] 
		FROM [dbo].[EmpCategory] ec WITH (NOLOCK) WHERE IsActive = 1
	END
	
	SELECT DISTINCT ee.[SysID]
			,ee.[EmpId]
			,ee.[DepartmentID]
			,d.NAME [DepartmentName]
			,ee.TeamID
			,et.[Code] EmpTeamCode
			,et.[Name] EmpTeamName
			,ee.[DomainUsername]
			,ee.[Code]
			,ee.[FullName]
			,ee.[NickName]
			,ee.[Enabled] IsActive
			,ee.[Password]
			,ee.[isDeleted]
			,ee.[EmpCategoryID]
			,ec.[CategoryName]			
			,ee.CardNumber
			,el.LocationID
			,l.VNMName LocationVNMName
			,l.ENGName LocationENGName
			,l.FloorName FloorName
			,ee.[IsLocal]
			,ee.[Roles]
			,ee.[JoinedDate]
			,ee.[DisableSync]
		FROM [dbo].[Employee] ee WITH (NOLOCK)
			INNER JOIN [dbo].[Department] d WITH (NOLOCK) ON ee.DepartmentID = d.DepartmentID
			INNER JOIN #Department tmpd WITH (NOLOCK) ON tmpd.DepartmentID = d.DepartmentID
			INNER JOIN #EmployeeType tmpec WITH (NOLOCK) ON ee.[EmpCategoryID] = tmpec.EmployeeTypeID
			LEFT JOIN [dbo].[EmpCategory] ec WITH (NOLOCK) ON ee.[EmpCategoryID] = ec.[EmpCategoryID]			
			LEFT JOIN [dbo].EmpLocation el WITH (NOLOCK) ON ee.[SysID] = el.[SysID]
			LEFT JOIN [dbo].Location l WITH (NOLOCK) ON el.LocationID = l.LocationID
			LEFT JOIN [dbo].[EmpTeam] et WITH (NOLOCK) ON ee.DepartmentID = et.DepartmentID
				AND ee.TeamID = et.EmpTeamID
			WHERE ee.[EmpId] >=99990 
				AND  ee.[isDeleted] = 0
				AND (@SysID IS NULL OR @SysID = ee.SysID )
				AND (@Status IS NULL OR @Status = ee.[Enabled] )
		ORDER BY ee.Code

	IF OBJECT_ID('tempdb..#Department') IS NOT NULL
	BEGIN
		DROP TABLE #Department
	END

	IF OBJECT_ID('tempdb..#EmployeeType') IS NOT NULL
	BEGIN
		DROP TABLE #EmployeeType
	END

	IF OBJECT_ID('tempdb..#tmpStatus') IS NOT NULL
	BEGIN
		DROP TABLE #tmpStatus
	END


END