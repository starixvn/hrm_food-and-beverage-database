USE [FBM]
GO
/****** Object:  UserDefinedFunction [dbo].[func_GetRegisterOrderMeal]    Script Date: 12/11/2014 5:53:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[func_GetRegisterOrderMeal]()
RETURNS INT
AS
BEGIN

	DECLARE @HH INT = DATEPART(HH,GETDATE())
		,@MM INT = DATEPART(MINUTE,GETDATE())
		,@MealID INT

	SELECT TOP 1 @MealID = MealID
	FROM dbo.Meal WITH(NOLOCK)
	WHERE (
			(
				DATEPART(HH, StartTime) < @HH
				OR (
					DATEPART(HH, StartTime) = @HH
					AND DATEPART(MINUTE, StartTime) <= @MM
					)
				)
			AND (
				DATEPART(HH, EndTime) > @HH
				OR (
					DATEPART(HH, EndTime) = @HH
					AND DATEPART(MINUTE, EndTime) >= @MM
					)
				)
			)
		OR (
			DATEPART(HH, StartTime) > (DATEPART(HH, EndTime))
			AND (
				(
					DATEPART(HH, StartTime) < @HH
					OR (
						DATEPART(HH, StartTime) = @HH
						AND DATEPART(MINUTE, StartTime) <= @MM
						)
					)
				OR (
					(DATEPART(HH, EndTime) > @HH)
					OR (
						DATEPART(HH, EndTime) = @HH
						AND DATEPART(MINUTE, EndTime) >= @MM
						)
					)
				)
			)
	ORDER BY MealID DESC
	IF @MealID IS NULL
		SET @MealID = 4

	RETURN @MealID

END
 





GO 

SELECT * FROM dbo.Meal WITH(NOLOCK)

DECLARE @MealID INT

SET @MealID = dbo.[func_GetRegisterOrderMeal]()

SELECT @MealID  MealID