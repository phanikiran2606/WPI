-- =============================================
-- Author:				change me
-- Create date:			change me
-- Automation Hub URL:	change me
-- =============================================
CREATE OR ALTER PROCEDURE [robot].[usp_Unproceessed_BU_Process_Name]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT 						
                         TOP (1) dest.AccData.Claim Reference --calling a column reference will set it as the queue item reference
						 , dest.AccData.ClaimID
						 , dest.AccData.SyncId
						 , -1 DataTypeId -- This should be -1 if not used
						 , 'ProcessName' ProcessName
						 
	INTO #tempClaims --ENABLE ME - disabled for testing
	FROM               
              dest.AccData INNER JOIN														
              dest.AccRegulator ON dest.AccData.ClaimID = dest.AccRegulator.ClaimID INNER JOIN
              dest.Member ON dest.AccData.MemberID = dest.Member.MemberID LEFT JOIN
			  RobotProcessing on RobotProcessing.ParentId = dest.AccData.SyncId
	WHERE    
		NOT (dest.AccRegulator.WorkStatusCode = '13' or dest.Member.DateDeceased IS NOT NULL)
		AND ((RobotProcessing.Processed IS NULL) OR (RobotProcessing.Processed = 0 AND GetDate() > dateadd(hour, 1, processedDate)))
		

	DECLARE @Claim VARCHAR(15);
	DECLARE @SyncId uniqueIdentifier;
	DECLARE @DataTypeId INT;
	DECLARE @ClaimId INT;
	DECLARE @ProcessName VARCHAR(20);
	
	BEGIN TRY
		BEGIN TRAN
		DECLARE MY_CURSOR CURSOR
			LOCAL STATIC READ_ONLY FORWARD_ONLY
		FOR
		SELECT ClaimId
		FROM #tempClaims

		OPEN MY_CURSOR
		FETCH NEXT FROM MY_CURSOR INTO @ClaimID
		WHILE @@FETCH_STATUS = 0
		BEGIN	
			SELECT @Claim = Claim
				, @DataTypeId = DataTypeId
				, @SyncId = SyncId
			FROM #tempClaims WHERE ClaimId  = @ClaimID;
						
			EXEC robot.usp_AddAutomationLog_Claim @Claim, 'Robot', '[robot].[usp_Unproceessed_BU_Process_Name]', N'Added to robot queue', 0, @ProcessName; 

			IF(@DataTypeId <> -1) --If there is an employer letter involved
			BEGIN
				INSERT INTO RobotProcessing Values (NEWID(), @SyncId, 0, GETDATE(), @DataTypeId);
			END 

			FETCH NEXT FROM MY_CURSOR INTO @ClaimID
		END
		CLOSE MY_CURSOR
		DEALLOCATE MY_CURSOR
		
		COMMIT

		SELECT * FROM #tempClaims
	END TRY
	BEGIN CATCH
		RAISERROR('Unable to create', 16, 1)
		ROLLBACK
	END CATCH
END


