USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MyOrderSysID]    Script Date: 10/27/2014 4:55:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE [dbo].[POS_Get_AllowToOrderBySysID] 
	@SysId INT
AS
/*
Created: Tom.Vo@2014-8-25
Task: Get Menu On Date By EmpID
DB: FBM
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @OnDate DATE
		,@MealID INT
		,@RetrictOrder BIT
		,@MaxOrderPerDay SMALLINT

	SELECT TOP 1 @RetrictOrder=  ecm.RetrictOrder
				,@MaxOrderPerDay  = ecm.MaxOrderPerDay
	FROM  [dbo].[Employee] ee WITH (NOLOCK)				
		INNER JOIN [dbo].[EmpCategoryMeal] ecm WITH (NOLOCK)
				ON ee.EmpCategoryID = ecm.EmpCategoryID
	WHERE ee.SysId = @SysID

	SET @OnDate = dbo.func_GetRegisterOrderDate()

	DECLARE @HH INT = DATEPART(HH,GETDATE())
		,@MM INT = DATEPART(MINUTE,GETDATE())

	SELECT TOP 1 @MealID = MealID
	FROM dbo.Meal WITH(NOLOCK)
	WHERE (
			(DATEPART(HH,RegisterTime) < @HH 
				OR (DATEPART(HH,RegisterTime) = @HH AND  DATEPART(MINUTE,RegisterTime) <= @MM)
			)
			AND (DATEPART(HH,EndTime) > @HH
				OR (DATEPART(HH,EndTime) = @HH AND  DATEPART(MINUTE,EndTime) >= @MM)		
			)
		
			)
		OR (
			DATEPART(HH,RegisterTime) > (DATEPART(HH,EndTime)) 
			AND ((DATEPART(HH,RegisterTime) < @HH 
					OR (
						DATEPART(HH,RegisterTime) = @HH AND  DATEPART(MINUTE,RegisterTime) <= @MM
					)
					)
				OR (
					(DATEPART(HH,EndTime) > @HH)
					OR (DATEPART(HH,EndTime) = @HH AND  DATEPART(MINUTE,EndTime) <= @MM)		 
			)
				)
			)
	ORDER BY MealID DESC
	
	IF OBJECT_ID('tempdb..#Order') IS NOT NULL
	BEGIN
		DROP TABLE..#Order
	END
	 
	CREATE TABLE #Order (OrderID INT,IsOwer INT,CurrentStatusID INT)

	INSERT INTO #Order (OrderID,IsOwer,CurrentStatusID)
	SELECT ord.OrderID
		,CASE WHEN ord.SysId = @SysId THEN 1 ELSE 0 END IsOwer
		,ord.CurrentStatusID
	FROM [dbo].[Order] ord WITH (NOLOCK)
		LEFT JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
		ON ord.OrderID = ordd.OrderID
			AND ordd.IsDeleted = 0
			AND ordd.IsCancel = 0
		LEFT JOIN [dbo].OrderAlternative orda WITH (NOLOCK)
		ON ord.OrderID = orda.OrderID
			AND orda.IsDeleted = 0
			AND orda.IsCancel = 0
		LEFT JOIN [dbo].OrderOptional ordo WITH (NOLOCK)
		ON ord.OrderID = ordo.OrderID
			AND ordo.IsDeleted = 0
	WHERE (--ord.SysId = @SysId
			--OR 
			(
				ordd.SysId = @SysId
				AND ordd.IsDeleted = 0
				AND ordd.IsCancel = 0
				)
			OR (
				orda.SysId = @SysId
				AND orda.IsDeleted = 0
				AND orda.IsCancel = 0
				)
			OR (
				ordo.SysId = @SysId
				AND ordo.IsDeleted = 0
				))
		AND ord.OnDate = @OnDate
		AND (@RetrictOrder = 0 OR ord.MealID =@MealID)
		AND ord.CurrentStatusID NOT IN (6, 99, 100)
	GROUP BY ord.OrderID
		,CASE WHEN ord.SysId = @SysId THEN 1 ELSE 0 END
		,ord.CurrentStatusID

	SELECT TOP 1 CASE WHEN @RetrictOrder = 0 AND OrderPerDay >0 THEN 'FALSE'
				WHEN @RetrictOrder = 1 AND OrderPerDay >= @MaxOrderPerDay THEN 'FALSE'
				ELSE 'TRUE' END IsAllowOrder
	FROM (
		SELECT  SUM(CASE WHEN CTE.CurrentStatusID IN (1,2,3) THEN 100 ELSE 1 END) OrderPerDay
		FROM #Order CTE
	) result
END


