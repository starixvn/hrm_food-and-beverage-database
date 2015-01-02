USE [FBM]
GO
/****** Object:  UserDefinedFunction [dbo].[func_GetRegisterMealID]    Script Date: 10/28/2014 8:58:00 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[func_GetRestrictMinuteOrder] ()
RETURNS INT
AS
BEGIN
	
	DECLARE @Restrict INT
	
	SELECT @Restrict=[Value]  FROM [dbo].[LookupData] WITH(NOLOCK) WHERE LookupId = 7 AND [Code] = 'ORDER'

	IF NOT ISNUMERIC(@Restrict)=1 
	BEGIN
		SET @Restrict = 0
	END	
	
	RETURN @Restrict
END
 


