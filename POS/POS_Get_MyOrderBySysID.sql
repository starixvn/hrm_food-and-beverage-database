USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MyOrderSysID]    Script Date: 10/27/2014 4:55:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[POS_Get_MyOrderBySysID] @SysId INT
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

	SET @OnDate = dbo.func_GetRegisterOrderDate()

	SELECT @MealID = dbo.func_GetRegisterOrderMeal()
	
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
		AND ord.MealID =@MealID
		AND ord.CurrentStatusID NOT IN (6, 99, 100)
	GROUP BY ord.OrderID
		,CASE WHEN ord.SysId = @SysId THEN 1 ELSE 0 END
		,ord.CurrentStatusID
	
	
	SELECT ord.OrderID
		,ord.OrderNo
		,SUM(ordd.QtyVeg+ordd.QtyNonVeg) QtyOrder
		,eMenu.ENGName MealENGName
		,eMenu.VNMName MealVNMName
		
		,ord.SysId OrderBy
		,ee.FullName OrderFullName
		,ee.NickName OrderNickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME CurrentStatusName
		,1 IsMainMenu	
		,0 isSideDish

	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].OrderDetail ordd WITH (NOLOCK)
		ON ord.OrderID = ordd.OrderID
		LEFT JOIN dbo.FoodMenu fm WITH (NOLOCK)
			ON fm.MenuID = ordd.MenuID
				AND fm.IsActive = 1
		LEFT JOIN [dbo].[EmpMeal] em WITH (NOLOCK)
			ON em.EmpMenuID = fm.EmpMenuID
				AND em.MealID = ord.MealID
				AND em.IsActive = 1
		INNER JOIN #Order tmpOrder
			ON ord.OrderID = tmpOrder.OrderID
		LEFT JOIN dbo.EmpMenu eMenu WITH(NOLOCK)
			ON em.EmpMenuID = eMenu.EmpMenuID
				AND eMenu.IsActive = 1
		LEFT JOIN dbo.Employee ee WITH (NOLOCK)
			ON ee.SysID = ord.SysId
		LEFT JOIN [dbo].[LookupData] lk WITH (NOLOCK)
			ON [LookupId] = 1
				AND lk.[Value] = ord.CurrentStatusID
	WHERE ordd.SysId = @SysId
		AND ordd.IsCancel = 0
		AND ordd.IsDeleted = 0
	GROUP BY ord.OrderID
		,ord.OrderNo
		,eMenu.ENGName
		,eMenu.VNMName
		,ord.SysId
		,ee.FullName
		,ee.NickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME
	UNION ALL
	SELECT ord.OrderID
		,ord.OrderNo
		,SUM(CONVERT(INT,ordA.Qty)) QtyOrder
		,altMenu.ENGName MealENGName
		,altMenu.VNMName MealVNMName
		,ord.SysId OrderBy
		,ee.FullName OrderFullName
		,ee.NickName OrderNickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME CurrentStatusName
		,0 IsMainMenu	
		,0 isSideDish
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].OrderAlternative ordA WITH (NOLOCK)
			ON ord.OrderID = ordA.OrderID
		LEFT JOIN dbo.AlternativeMenu altMenu WITH (NOLOCK)
			ON altMenu.AltMenuID = ordA.AltMenuID		
		INNER JOIN #Order tmpOrder
			ON ord.OrderID = tmpOrder.OrderID		
		LEFT JOIN dbo.Employee ee WITH (NOLOCK)
			ON ee.SysID = ord.SysId
		LEFT JOIN [dbo].[LookupData] lk WITH (NOLOCK)
			ON [LookupId] = 1
				AND lk.[Value] = ord.CurrentStatusID
	WHERE ordA.SysId = @SysId
		AND ordA.IsCancel = 0
		AND ordA.IsDeleted = 0
	GROUP BY ord.OrderID
		,ord.OrderNo
		,altMenu.ENGName
		,altMenu.VNMName
		,ord.SysId
		,ee.FullName
		,ee.NickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME
	UNION ALL
	SELECT ord.OrderID
		,ord.OrderNo
		,SUM(CONVERT(INT,ordA.Qty)) QtyOrder
		,f.ENGName MealENGName
		,f.VNMName MealVNMName
		,ord.SysId OrderBy
		,ee.FullName OrderFullName
		,ee.NickName OrderNickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME CurrentStatusName
		,0 IsMainMenu	
		,1 isSideDish
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].OrderOptional ordA WITH (NOLOCK)
			ON ord.OrderID = ordA.OrderID
		LEFT JOIN dbo.Food f WITH (NOLOCK)
			ON f.FoodID = ordA.FoodID
		INNER JOIN #Order tmpOrder
			ON ord.OrderID = tmpOrder.OrderID
		LEFT JOIN dbo.Employee ee WITH (NOLOCK)
			ON ee.SysID = ord.SysId
		LEFT JOIN [dbo].[LookupData] lk WITH (NOLOCK)
			ON [LookupId] = 1
				AND lk.[Value] = ord.CurrentStatusID
	WHERE ordA.SysId = @SysId
		AND ordA.IsDeleted = 0
	GROUP BY ord.OrderID
		,ord.OrderNo
		,f.ENGName
		,f.VNMName
		,ord.SysId
		,ee.FullName
		,ee.NickName
		,ord.OrderFrom
		,ord.CurrentStatusID
		,lk.NAME
END


