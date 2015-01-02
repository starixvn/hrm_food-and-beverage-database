USE [FBM]
GO
/****** Object:  UserDefinedFunction [dbo].[func_GetRegisterMealID]    Script Date: 10/28/2014 8:58:00 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[func_GetRestrictOtherCompany] ()
RETURNS BIT
AS
BEGIN
	
	DECLARE @Restrict BIT
	
	SELECT @Restrict=[Value]  FROM [dbo].[LookupData] WITH(NOLOCK) WHERE LookupId = 7 AND [Code] = 'Using'

	IF NOT ISNUMERIC(@Restrict)=1 
	BEGIN
		SET @Restrict = 0
	END	
	
	RETURN @Restrict
END
 


