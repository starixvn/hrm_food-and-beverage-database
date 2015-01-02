USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[POS_Get_MyStatusBySysID]    Script Date: 11/27/2014 2:21:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[POS_Get_MyStatusBySysID] @SysId INT
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
		,@IsHaveAltMenu INT
		,@IsAllowOrder BIT=1
		,@RetrictOrder BIT
		,@MaxOrderPerDay SMALLINT
		,@OrderID INT

	SELECT TOP 1 @RetrictOrder=  ecm.RetrictOrder
				,@MaxOrderPerDay  = ecm.MaxOrderPerDay
	FROM  [dbo].[Employee] ee WITH (NOLOCK)				
		INNER JOIN [dbo].[EmpCategoryMeal] ecm WITH (NOLOCK)
				ON ee.EmpCategoryID = ecm.EmpCategoryID
	WHERE ee.SysId = @SysID


	SET @OnDate = dbo.func_GetRegisterOrderDate()

	SELECT @MealID = dbo.func_GetRegisterOrderMeal()
	
	SELECT TOP 1
		@IsHaveAltMenu = CASE WHEN alt.[AltMenuID] IS NOT NULL THEN 1 ELSE 0 END
	FROM dbo.Employee ee WITH (NOLOCK)		
	INNER JOIN [dbo].[AlternativeMenuEmpTyPe] sub WITH(NOLOCK)
				ON ee.[EmpCategoryID] = sub.[EmpCategoryID] AND sub.IsActive = 1
	INNER JOIN  [dbo].[AlternativeMenu] alt WITH(NOLOCK)		
				ON alt.[AltMenuID] = sub.AltMenuID  AND alt.IsActive = 1
	WHERE ee.SysId = @SysId

	SELECT @IsHaveAltMenu = ISNULL(@IsHaveAltMenu,0)

	;WITH CTE (
		OrderID
		,SysId
		,CurrentStatusID
		,Qty
		)
	AS (
		SELECT ord.OrderID
			,orda.SysId
			,ord.CurrentStatusID
			,orda.Qty
		FROM [dbo].[Order] ord WITH (NOLOCK)
			LEFT JOIN [dbo].OrderAlternative orda WITH (NOLOCK)
			ON ord.OrderID = orda.OrderID
		WHERE ord.OnDate = @OnDate			
		AND (@RetrictOrder = 1 OR ord.MealID =@MealID)
			AND ord.CurrentStatusID NOT IN (6, 99, 100)
			AND (
				orda.IsDeleted = 0
				AND orda.IsCancel = 0
				)
			AND orda.SysId = @SysId
	
		UNION ALL
		SELECT ord.OrderID
			,ordd.SysId
			,ord.CurrentStatusID
			,ordd.QtyNonVeg+ordd.QtyVeg AS Qty
		FROM [dbo].[Order] ord WITH (NOLOCK)
			LEFT JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
			ON ord.OrderID = ordd.OrderID
		WHERE ord.OnDate = @OnDate
			AND (@RetrictOrder = 1 OR ord.MealID =@MealID)
			AND ord.CurrentStatusID NOT IN (6, 99, 100)
			AND (
				ordd.IsDeleted = 0
				AND ordd.IsCancel = 0
				)
			AND ordd.SysId = @SysId
		)
	SELECT TOP 1 @IsAllowOrder= CASE WHEN @RetrictOrder = 0 AND OrderPerDay >0 THEN 'FALSE'
				WHEN @RetrictOrder = 1 AND OrderPerDay >= @MaxOrderPerDay THEN 'FALSE'
				ELSE 'TRUE' END 
	FROM (
		SELECT  SUM(CASE WHEN CTE.CurrentStatusID IN (1,2,3) THEN 100 ELSE Qty END) OrderPerDay
		FROM CTE CTE
	) result
	
	IF NOT EXISTS(
	SELECT TOP 1 1 FROM dbo.Employee ee WITH(NOLOCK) 
		LEFT JOIN dbo.EmpRegisterFood erf WITH(NOLOCK)
			ON erf.WorkDate =@OnDate
			AND erf.MealID = @MealID
			AND erf.SysID = @SysId
		INNER JOIN [dbo].[EmpMenuSub] emus WITH(NOLOCK)
			ON ee.EmpCategoryID = emus.EmpCategoryID
				AND emus.IsActive = 1
		INNER JOIN [dbo].[EmpMeal] em WITH(NOLOCK)
			ON em.EmpMenuID = emus.EmpMenuID
				AND em.[MealID] = @MealID
				AND em.IsActive = 1
		INNER JOIN dbo.EmpMenu eMenu WITH(NOLOCK)
			ON em.EmpMenuID = eMenu.EmpMenuID
				AND ISNULL(erf.IsVegetarian,0) = eMenu.IsVegetarian
				AND eMenu.IsActive = 1
		INNER JOIN dbo.FoodMenu fm WITH (NOLOCK)			
				ON fm.EmpMenuID = eMenu.EmpMenuID	
					AND  fm.IsActive = 1
					AND fm.OnDate = @OnDate
	WHERE ee.SysId = @SysId
	)
	BEGIN
		SELECT @IsAllowOrder = 'FALSE'
	END

	SELECT @OrderID = MAX(OrderID)
	FROM (
	SELECT  MAX(ordd.OrderID) OrderID
		FROM [dbo].[Order] ord WITH (NOLOCK)
			INNER JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
			ON ord.OrderID = ordd.OrderID
		WHERE ordd.SysId = @SysId
			AND ord.OnDate = @OnDate
			AND ord.MealID = @MealID
			AND ord.CurrentStatusID NOT IN (6, 99, 100)
			AND ordd.IsCancel = 0
			AND ordd.IsDeleted = 0
	UNION ALL
	SELECT MAX(ordd.OrderID) OrderID 
		FROM [dbo].[Order] ord WITH (NOLOCK)
			INNER JOIN [dbo].OrderAlternative ordd WITH (NOLOCK)
			ON ord.OrderID = ordd.OrderID
		WHERE ordd.SysId = @SysId
			AND ord.OnDate = @OnDate
			AND ord.CurrentStatusID NOT IN (6, 99, 100)
			AND ord.MealID = @MealID
			AND ordd.IsCancel = 0
			AND ordd.IsDeleted = 0
	) tblOrder

	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.Employee ee WITH (NOLOCK)
				LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
				ON erf.WorkDate = @OnDate
					AND erf.MealID = @MealID
					AND erf.SysId = ee.SysId
				INNER JOIN [dbo].[EmpMenuSub] emus WITH (NOLOCK)
				ON ee.EmpCategoryID = emus.EmpCategoryID
					AND emus.IsActive = 1
				INNER JOIN [dbo].[EmpMeal] em WITH (NOLOCK)
				ON em.EmpMenuID = emus.EmpMenuID
					AND em.IsActive = 1
					AND em.MealID = @MealID
				INNER JOIN dbo.EmpMenu eMenu WITH (NOLOCK)
				ON em.EmpMenuID = eMenu.EmpMenuID
					AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
					AND eMenu.IsActive = 1
				INNER JOIN dbo.FoodMenu fm WITH (NOLOCK)
				ON fm.EmpMenuID = em.EmpMenuID
					AND fm.OnDate = @OnDate
					AND fm.IsActive = 1
			WHERE ee.SysId = @SysId
			)
	BEGIN
		SELECT DISTINCT me.[MealID]
			,me.ENGName MealEngName
			,me.VNMName MealVNMName
			,NULL OrderID
			,NULL OrderNo
			,NULL OrderTime
			,CAST('FALSE' AS BIT) TakeAway
			,NULL [RegisterDate]
			,NULL [ReceiveOrderDate]
			,NULL [DeliverOrderDate]
			,NULL IsDeleted
			,NULL IsCancel
			,NULL Remark
			,ee.Phone
			,@IsAllowOrder IsAllowOrder
			,NULL OrderBy
			,NULL OrderCode
			,NULL OrderFullName
			,NULL OrderNickName
			,ee.[SysID]
			,ee.[EmpId]
			,ee.[DomainUsername]
			,ee.[Code]
			,ee.[FullName]
			,ee.[NickName]
			,NULL CurrentStatusID
			,NULL CurrentStatusName
			,CONVERT(INT, - 1) MenuID
			,'No menu available!' MenuEngName
			,'No menu available!' MenuVNMName
			,ISNULL(erf.IsVegetarian, 0) [IsVegetarian]
			,1 IsMainMenu
			,@IsHaveAltMenu IsHaveAltMenu
			,NULL LocationID --lo.LocationID 
			,NULL LocationENGName --lo.ENGName 
			,NULL LocationVNMName --lo.VNMName 
		FROM dbo.Employee ee WITH (NOLOCK)
			LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
			ON erf.WorkDate = @OnDate
				AND erf.MealID = @MealID
				AND erf.SysId = ee.SysId
			LEFT JOIN [dbo].[Meal] me WITH (NOLOCK)
			ON me.[MealID] = @MealID
				AND me.ActiveID = 1
		WHERE ee.SysId = @SysId
	END
	ELSE IF EXISTS (
			SELECT TOP 1 1
			FROM [dbo].[Order] ord WITH (NOLOCK)
				INNER JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
				ON ord.OrderID = ordd.OrderID
			WHERE ordd.SysId = @SysId
				AND ord.OnDate = @OnDate
				AND ord.MealID = @MealID
				AND ord.CurrentStatusID NOT IN (6, 99, 100)
				AND ordd.IsCancel = 0
				AND ordd.IsDeleted = 0
				AND ordd.OrderID = @OrderID
			)
	BEGIN
		--SELECT @OrderID = MAX(ordd.OrderID)
		--FROM [dbo].[Order] ord WITH (NOLOCK)
		--	INNER JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
		--	ON ord.OrderID = ordd.OrderID
		--WHERE ordd.SysId = @SysId
		--	AND ord.OnDate = @OnDate
		--	AND ord.MealID = @MealID
		--	AND ord.CurrentStatusID NOT IN (6, 99, 100)
		--	AND ordd.IsCancel = 0
		--	AND ordd.IsDeleted = 0

		SELECT DISTINCT me.[MealID]
			,me.ENGName MealEngName
			,me.VNMName MealVNMName
			,ord.OrderID
			,ord.OrderNo OrderNo
			,ord.OrderTime
			--,CAST(ord.TakeAway AS BIT)  TakeAway
			,CAST('FALSE' AS BIT) TakeAway
			,ord.RegisterDate [RegisterDate]
			,ord.PrintInvoiceDate [ReceiveOrderDate]
			,ord.DeliverDate [DeliverOrderDate]
			,ordd.IsDeleted
			,ordd.IsCancel
			,'' Remark --ord.Remark 
			,ee.Phone
			,CASE 
				WHEN eMenu.EmpMenuID IS NULL THEN CONVERT(BIT, 0)
				ELSE @IsAllowOrder
				END IsAllowOrder
			,ord.SysId OrderBy
			,ee.Code OrderCode
			,ee.FullName OrderFullName
			,ee.NickName OrderNickName
			,eem.[SysID]
			,eem.[EmpId]
			,eem.[DomainUsername]
			,eem.[Code]
			,eem.[FullName]
			,eem.[NickName]
			,CASE 
				WHEN ISNULL(ordd.IsCancel, 0) = 1 THEN NULL
				ELSE ord.CurrentStatusID
				END CurrentStatusID
			,CASE 
				WHEN ISNULL(ordd.IsCancel, 0) = 1 THEN NULL
				ELSE lk.NAME
				END CurrentStatusName
			,CASE 
				WHEN eMenu.EmpMenuID IS NULL THEN CONVERT(INT, - 1)
				ELSE CAST(eMenu.EmpMenuID AS INT)
				END MenuID
			,CASE 
				WHEN eMenu.EmpMenuID IS NULL THEN 'No menu available!'
				ELSE eMenu.ENGName
				END MenuEngName
			,CASE 
				WHEN eMenu.EmpMenuID IS NULL THEN 'No menu available!'
				ELSE eMenu.VNMName
				END MenuVNMName
			,eMenu.[IsVegetarian]
			,1 IsMainMenu
			,@IsHaveAltMenu IsHaveAltMenu
			,NULL LocationID --lo.LocationID 
			,NULL LocationENGName --lo.ENGName 
			,NULL LocationVNMName --lo.VNMName 
		FROM [dbo].[Order] ord WITH (NOLOCK)
			INNER JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
			ON ord.OrderID = ordd.OrderID
			LEFT JOIN [dbo].[LookupData] lk WITH (NOLOCK)
			ON [LookupId] = 1
				AND lk.[Value] = ord.CurrentStatusID
			LEFT JOIN dbo.Employee ee WITH (NOLOCK)
			ON ee.SysID = ord.SysId
			LEFT JOIN dbo.Employee eem WITH (NOLOCK)
			ON eem.SysID = ordd.SysId
			LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
			ON erf.WorkDate = @OnDate
				AND erf.MealID = @MealID
				AND erf.SysId = eem.SysId
			LEFT JOIN dbo.FoodMenu fm WITH (NOLOCK)
			ON fm.MenuID = ordd.MenuID
				AND fm.IsActive = 1
			LEFT JOIN [dbo].[EmpMeal] em WITH (NOLOCK)
			ON em.EmpMenuID = fm.EmpMenuID
				AND em.IsActive = 1
				AND em.MealID = ord.MealID
			LEFT JOIN dbo.EmpMenu eMenu WITH (NOLOCK)
			ON em.EmpMenuID = eMenu.EmpMenuID
				AND eMenu.IsActive = 1
				AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
			LEFT JOIN [dbo].[Meal] me WITH (NOLOCK)
			ON em.[MealID] = me.MealID
				AND me.ActiveID = 1
		WHERE ord.OrderID = @OrderID
			AND (ordd.SysId = @SysId)
	END
	ELSE IF EXISTS (
			SELECT TOP 1 1
			FROM [dbo].[Order] ord WITH (NOLOCK)
				INNER JOIN [dbo].OrderAlternative ordd WITH (NOLOCK)
				ON ord.OrderID = ordd.OrderID
			WHERE ordd.SysId = @SysId
				AND ord.OnDate = @OnDate
				AND ord.MealID = @MealID
				AND ord.CurrentStatusID NOT IN (6, 99, 100)
				AND ordd.IsCancel = 0
				AND ordd.IsDeleted = 0				
				AND ordd.OrderID = @OrderID
			)
	BEGIN
		--SELECT @OrderID = MAX(ordd.OrderID)
		--FROM [dbo].[Order] ord WITH (NOLOCK)
		--	INNER JOIN [dbo].OrderAlternative ordd WITH (NOLOCK)
		--	ON ord.OrderID = ordd.OrderID
		--WHERE ordd.SysId = @SysId
		--	AND ord.OnDate = @OnDate
		--	AND ord.CurrentStatusID NOT IN (6, 99, 100)
		--	AND ord.MealID = @MealID
		--	AND ordd.IsCancel = 0
		--	AND ordd.IsDeleted = 0

		SELECT TOP 1 me.[MealID]
			,me.ENGName MealEngName
			,me.VNMName MealVNMName
			,ord.OrderID
			,ord.OrderNo OrderNo
			,ord.OrderTime
			--,CAST(ord.TakeAway AS BIT)  TakeAway
			,CAST('FALSE' AS BIT) TakeAway
			,ord.RegisterDate [RegisterDate]
			,ord.PrintInvoiceDate [ReceiveOrderDate]
			,ord.DeliverDate [DeliverOrderDate]
			,ordalt.IsDeleted
			,ordalt.IsCancel
			,'' Remark
			,ee.Phone
			,CASE 
				WHEN @IsAllowOrder = 'FALSE' THEN CONVERT(BIT, 0)
				ELSE @IsAllowOrder
				END IsAllowOrder
			,ord.SysId OrderBy
			,ee.Code OrderCode
			,ee.FullName OrderFullName
			,ee.NickName OrderNickName
			,eem.[SysID]
			,eem.[EmpId]
			,eem.[DomainUsername]
			,eem.[Code]
			,eem.[FullName]
			,eem.[NickName]
			,CASE 
				WHEN ISNULL(ordalt.IsCancel, 0) = 1 THEN NULL
				ELSE ord.CurrentStatusID
				END CurrentStatusID
			,CASE 
				WHEN ISNULL(ordalt.IsCancel, 0) = 1 THEN NULL
				ELSE lk.NAME
				END CurrentStatusName
			,CAST(eMenu.EmpMenuID AS INT) MenuID
			,eMenu.ENGName MenuEngName
			,eMenu.VNMName MenuVNMName
			,0 [IsVegetarian]
			,0 IsMainMenu
			,1 IsHaveAltMenu
			,NULL LocationID --lo.LocationID 
			,NULL LocationENGName --lo.ENGName 
			,NULL LocationVNMName --lo.VNMName 
			--,*
		FROM [dbo].[Order] ord WITH (NOLOCK)
			INNER JOIN [dbo].OrderAlternative ordalt WITH (NOLOCK)
			ON ord.OrderID = ordalt.OrderID
			INNER JOIN dbo.AlternativeMenu altMu WITH (NOLOCK)
			ON altMu.AltMenuID = ordalt.AltMenuID
			LEFT JOIN [dbo].[LookupData] lk WITH (NOLOCK)
			ON [LookupId] = 1
				AND lk.[Value] = ord.CurrentStatusID
			LEFT JOIN dbo.Employee ee WITH (NOLOCK)
			ON ee.SysID = ord.SysId
			LEFT JOIN dbo.Employee eem WITH (NOLOCK)
			ON eem.SysID = ordalt.SysId
			LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
			ON erf.WorkDate = @OnDate
				AND erf.MealID = @MealID
				AND erf.SysId = @SysId
			LEFT JOIN [dbo].[EmpMenuSub] emus WITH (NOLOCK)
			ON eem.EmpCategoryID = emus.EmpCategoryID
				AND emus.IsActive = 1
			LEFT JOIN [dbo].[EmpMeal] em WITH (NOLOCK)
			ON em.EmpMenuID = emus.EmpMenuID
				AND em.IsActive = 1
				AND em.MealID = @MealID
			LEFT JOIN dbo.EmpMenu eMenu WITH (NOLOCK)
			ON em.EmpMenuID = eMenu.EmpMenuID
				AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
				AND eMenu.IsActive = 1
			LEFT JOIN dbo.FoodMenu fm WITH (NOLOCK)
			ON fm.EmpMenuID = eMenu.EmpMenuID
				AND fm.OnDate = @OnDate
				AND fm.IsActive = 1
			LEFT JOIN [dbo].[Meal] me WITH (NOLOCK)
			ON ord.[MealID] = me.MealID
				AND me.ActiveID = 1
		WHERE ord.OrderID = @OrderID
			AND (ordalt.SysId = @SysId)
		ORDER BY IsAllowOrder
			,eMenu.EmpMenuID DESC
	END
	ELSE
	BEGIN
		SELECT DISTINCT me.[MealID]
			,me.ENGName MealEngName
			,me.VNMName MealVNMName
			,NULL OrderID
			,NULL OrderNo
			,NULL OrderTime
			,CAST('FALSE' AS BIT) TakeAway
			,NULL [RegisterDate]
			,NULL [ReceiveOrderDate]
			,NULL [DeliverOrderDate]
			,NULL IsDeleted
			,NULL IsCancel
			,NULL Remark
			,ee.Phone
			,@IsAllowOrder IsAllowOrder
			,NULL OrderBy
			,NULL OrderCode
			,NULL OrderFullName
			,NULL OrderNickName
			,ee.[SysID]
			,ee.[EmpId]
			,ee.[DomainUsername]
			,ee.[Code]
			,ee.[FullName]
			,ee.[NickName]
			,NULL CurrentStatusID
			,NULL CurrentStatusName
			,CASE 
				WHEN ISNULL(fm.IsActive, 0) = 0 THEN CONVERT(INT, - 1)
				ELSE CAST(eMenu.EmpMenuID AS INT)
				END MenuID
			,CASE 
				WHEN ISNULL(fm.IsActive, 0) = 0 THEN 'No menu available!'
				ELSE eMenu.ENGName
				END MenuEngName
			,CASE 
				WHEN ISNULL(fm.IsActive, 0) = 0 THEN 'No menu available!'
				ELSE eMenu.VNMName
				END MenuVNMName
			,eMenu.[IsVegetarian]
			,1 IsMainMenu
			,@IsHaveAltMenu IsHaveAltMenu
			,NULL LocationID --lo.LocationID 
			,NULL LocationENGName --lo.ENGName 
			,NULL LocationVNMName --lo.VNMName 
		FROM dbo.Employee ee WITH (NOLOCK)
			LEFT JOIN dbo.EmpRegisterFood erf WITH (NOLOCK)
			ON erf.WorkDate = @OnDate
				AND erf.MealID = @MealID
				AND erf.SysId = ee.SysId
			INNER JOIN [dbo].[EmpMenuSub] emus WITH (NOLOCK)
			ON ee.EmpCategoryID = emus.EmpCategoryID
				AND emus.IsActive = 1
			INNER JOIN [dbo].[EmpMeal] em WITH (NOLOCK)
			ON em.EmpMenuID = emus.EmpMenuID
				AND em.IsActive = 1
				AND em.MealID = @MealID
			INNER JOIN dbo.EmpMenu eMenu WITH (NOLOCK)
			ON em.EmpMenuID = eMenu.EmpMenuID
				AND eMenu.IsVegetarian = ISNULL(erf.IsVegetarian, 0)
				AND eMenu.IsActive = 1
			LEFT JOIN dbo.FoodMenu fm WITH (NOLOCK)
			ON fm.EmpMenuID = em.EmpMenuID
				AND fm.OnDate = @OnDate
				AND fm.IsActive = 1
			LEFT JOIN [dbo].[Meal] me WITH (NOLOCK)
			ON em.[MealID] = me.MealID
				AND me.ActiveID = 1
		WHERE ee.SysId = @SysId
	END


END


