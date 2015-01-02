USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[FoodMenu_RecordHistory]    Script Date: 10/27/2014 4:54:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[FoodMenu_RecordHistory]
	@MenuID INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @EffectedDate DATE =GETDATE()

	INSERT INTO dbo.HisEmpMenuActive( EmpMenuID
		,IsVegetarian
		,EmpCategoryID
		,MealID
		,EffectedFromDate
		,EffectedToDate)
	SELECT emn.EmpMenuID
		,emn.IsVegetarian
		,emns.EmpCategoryID
		,emmeal.MealID
		,emn.EffectedDate EffectedFromDate
		,NULL EffectedToDate	
	FROM dbo.EmpMenu emn WITH (NOLOCK)
	INNER JOIN dbo.EmpMenuSub emns WITH (NOLOCK) ON emns.EmpMenuID = emn.EmpMenuID
	INNER JOIN dbo.EmpMeal emmeal WITH (NOLOCK) ON emmeal.EmpMenuID = emns.EmpMenuID 
	LEFT JOIN dbo.HisEmpMenuActive hisemn
		ON emmeal.EmpMenuID = hisemn.EmpMenuID 
		AND emns.EmpCategoryID = hisemn.EmpCategoryID 
		AND emmeal.MealID = hisemn.MealID 
	WHERE emn.EmpMenuID = @MenuID AND emn.IsActive = 1
	AND hisemn.EmpMenuID IS NULL
		
	UPDATE hisemn
	SET hisemn.IsVegetarian = emn.IsVegetarian
	FROM dbo.HisEmpMenuActive hisemn
	INNER JOIN dbo.EmpMenu emn WITH (ROWLOCK,UPDLOCK)
		ON emn.EmpMenuID = hisemn.EmpMenuID 
	WHERE emn.EmpMenuID = @MenuID AND emn.IsActive = 1 AND hisemn.EffectedToDate IS NULL


	UPDATE hisemn
	SET hisemn.EffectedToDate = @EffectedDate
	FROM dbo.HisEmpMenuActive hisemn
	INNER JOIN dbo.EmpMenu emn WITH (ROWLOCK,UPDLOCK)
		ON emn.EmpMenuID = hisemn.EmpMenuID 
	WHERE emn.EmpMenuID = @MenuID AND emn.IsActive = 0 AND hisemn.EffectedToDate IS NULL

	
	UPDATE hisemn
	SET hisemn.EffectedToDate = @EffectedDate
	FROM dbo.HisEmpMenuActive hisemn
	INNER JOIN dbo.EmpMenu emn WITH (ROWLOCK,UPDLOCK)
		ON emn.EmpMenuID = hisemn.EmpMenuID
	INNER JOIN dbo.EmpMenuSub emns WITH (NOLOCK) 
		ON emns.EmpMenuID = emn.EmpMenuID
			AND emns.EmpCategoryID = hisemn.EmpCategoryID
	WHERE emn.EmpMenuID = @MenuID AND (emn.IsActive = 0 OR emns.IsActive = 0 ) 
		AND hisemn.EffectedToDate IS NULL
	
	UPDATE hisemn
	SET hisemn.EffectedToDate = @EffectedDate
	FROM dbo.HisEmpMenuActive hisemn
	INNER JOIN dbo.EmpMenu emn WITH (ROWLOCK,UPDLOCK)
		ON emn.EmpMenuID = hisemn.EmpMenuID
	INNER JOIN dbo.EmpMenuSub emns WITH (NOLOCK) 
		ON emns.EmpMenuID = emn.EmpMenuID
			AND emns.EmpCategoryID = hisemn.EmpCategoryID
	INNER JOIN dbo.EmpMeal emmeal WITH (NOLOCK) 
		ON emmeal.EmpMenuID = emns.EmpMenuID 
			AND emmeal.MealID = hisemn.MealID
	WHERE emn.EmpMenuID = @MenuID AND (emn.IsActive = 0 OR emns.IsActive = 0 OR emmeal.IsActive = 0 ) 
		AND hisemn.EffectedToDate IS NULL

	
	UPDATE hisemn
	SET hisemn.EffectedToDate = NULL
	FROM dbo.HisEmpMenuActive hisemn
	INNER JOIN dbo.EmpMenu emn WITH (ROWLOCK,UPDLOCK)
		ON emn.EmpMenuID = hisemn.EmpMenuID
	INNER JOIN dbo.EmpMenuSub emns WITH (NOLOCK) 
		ON emns.EmpMenuID = emn.EmpMenuID
			AND emns.EmpCategoryID = hisemn.EmpCategoryID
	INNER JOIN dbo.EmpMeal emmeal WITH (NOLOCK) 
		ON emmeal.EmpMenuID = emns.EmpMenuID 
			AND emmeal.MealID = hisemn.MealID
	WHERE emn.EmpMenuID = @MenuID AND (emn.IsActive = 1 AND emns.IsActive = 1 AND emmeal.IsActive = 1 ) 
		AND hisemn.EffectedToDate = @EffectedDate

END

GO

--TRUNCATE TABLE  dbo.HisEmpMenuActive 

EXEC [dbo].[FoodMenu_RecordHistory] 	@MenuID = 10