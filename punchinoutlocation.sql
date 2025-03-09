CREATE OR ALTER PROCEDURE dbo.ValidateEmployeePunchWithLocation
    @EmpCode VARCHAR(100),
    @PunchInDateTime DATETIME,
    @PunchOutDateTime DATETIME = NULL,
    @Latitude DECIMAL(10,7),  -- Latitude of the punch-in location
    @Longitude DECIMAL(10,7), -- Longitude of the punch-in location
    @IsValidPunchIn BIT OUTPUT,
    @IsValidPunchOut BIT OUTPUT,
    @IsValidLocation BIT OUTPUT,
    @Message VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables for punch validation
    DECLARE @ShiftID VARCHAR(50);
    DECLARE @InTime TIME;
    DECLARE @OutTime TIME;
    DECLARE @PreTime INT;
    DECLARE @PostTime INT;
    DECLARE @ShiftStartDate DATE;
    DECLARE @ShiftEndDate DATE;
    DECLARE @ShiftDetailsJson NVARCHAR(MAX);

    -- Declare variables for location validation
    DECLARE @LocationDetailsJson NVARCHAR(MAX);

    -- Punch validation variables
    DECLARE @PunchInTime TIME = CAST(@PunchInDateTime AS TIME);
    DECLARE @PunchOutTime TIME = CAST(COALESCE(@PunchOutDateTime, @PunchInDateTime) AS TIME); -- Default to PunchInTime if NULL
    DECLARE @PunchDate DATE = CAST(@PunchInDateTime AS DATE);

    -- Initialize outputs
    SET @IsValidPunchIn = 0;
    SET @IsValidPunchOut = 0;
    SET @IsValidLocation = 0;
    SET @Message = '';

    -- Get ShiftDetails and LocationDetails JSON
    SELECT 
        @ShiftDetailsJson = ShiftDetails,
        @LocationDetailsJson = LocationDetails
    FROM dbo.FlatTable
    WHERE EmpCode = @EmpCode;

    IF @ShiftDetailsJson IS NULL AND @LocationDetailsJson IS NULL
    BEGIN
        SET @Message = 'No shift or location details found for employee ' + @EmpCode;
        RETURN;
    END;

    IF @ShiftDetailsJson IS NOT NULL AND ISJSON(@ShiftDetailsJson) = 0
    BEGIN
        SET @Message = 'Invalid JSON format in ShiftDetails for employee ' + @EmpCode + ': ' + LEFT(@ShiftDetailsJson, 100);
        RETURN;
    END;

    IF @LocationDetailsJson IS NOT NULL AND ISJSON(@LocationDetailsJson) = 0
    BEGIN
        SET @Message = 'Invalid JSON format in LocationDetails for employee ' + @EmpCode + ': ' + LEFT(@LocationDetailsJson, 100);
        RETURN;
    END;

    -- Parse the JSON with detailed error handling
    BEGIN TRY
        -- Punch Validation
        IF @ShiftDetailsJson IS NOT NULL
        BEGIN
            SELECT TOP 1
                @ShiftID = JSON_VALUE(shift.value, '$.ShiftID'),
                @InTime = CAST(JSON_VALUE(JSON_QUERY(shift.value, '$.ShiftDetails'), '$.InTime') AS TIME),
                @OutTime = CAST(JSON_VALUE(JSON_QUERY(shift.value, '$.ShiftDetails'), '$.OutTime') AS TIME),
                @PreTime = COALESCE(CAST(JSON_VALUE(JSON_QUERY(shift.value, '$.ShiftDetails'), '$.PreTime') AS INT), 0),
                @PostTime = COALESCE(CAST(JSON_VALUE(JSON_QUERY(shift.value, '$.ShiftDetails'), '$.PostTime') AS INT), 0),
                @ShiftStartDate = CAST(JSON_VALUE(range.value, '$.RangeStart') AS DATE),
                @ShiftEndDate = CAST(JSON_VALUE(range.value, '$.RangeEnd') AS DATE)
            FROM OPENJSON(@ShiftDetailsJson) AS shift
            CROSS APPLY OPENJSON(JSON_QUERY(shift.value, '$.ShiftDetails'), '$.ShiftRanges') AS range
            WHERE @PunchDate BETWEEN CAST(JSON_VALUE(range.value, '$.RangeStart') AS DATE)
                                AND CAST(JSON_VALUE(range.value, '$.RangeEnd') AS DATE);

            IF @ShiftID IS NOT NULL
            BEGIN
                -- Calculate valid punch windows
                DECLARE @ValidPunchInStart TIME = DATEADD(MINUTE, -@PreTime, @InTime);
                DECLARE @ValidPunchInEnd TIME = @InTime;
                DECLARE @ValidPunchOutStart TIME = @OutTime;
                DECLARE @ValidPunchOutEnd TIME = DATEADD(MINUTE, @PostTime, @OutTime);

                -- Validate Punch-In (Ensure all are TIME types)
                IF @PunchInTime >= @ValidPunchInStart AND @PunchInTime <= @ValidPunchInEnd
                BEGIN
                    SET @IsValidPunchIn = 1;
                    SET @Message = @Message + 'Punch-In at ' + CONVERT(VARCHAR, @PunchInTime, 108) + 
                                   ' is valid for ShiftID ' + @ShiftID + 
                                   ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                                   'Allowed punch-in window: ' + CONVERT(VARCHAR, @ValidPunchInStart, 108) + 
                                   ' to ' + CONVERT(VARCHAR, @ValidPunchInEnd, 108) + '. ';
                END
                ELSE
                BEGIN
                    SET @Message = @Message + 'Punch-In at ' + CONVERT(VARCHAR, @PunchInTime, 108) + 
                                   ' is invalid for ShiftID ' + @ShiftID + 
                                   ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                                   'Allowed punch-in window: ' + CONVERT(VARCHAR, @ValidPunchInStart, 108) + 
                                   ' to ' + CONVERT(VARCHAR, @ValidPunchInEnd, 108) + '. ';
                END;

                -- Validate Punch-Out
                IF @PunchOutDateTime IS NOT NULL
                BEGIN
                    IF @PunchOutTime >= @ValidPunchOutStart AND @PunchOutTime <= @ValidPunchOutEnd
                    BEGIN
                        SET @IsValidPunchOut = 1;
                        SET @Message = @Message + 'Punch-Out at ' + CONVERT(VARCHAR, @PunchOutTime, 108) + 
                                       ' is valid for ShiftID ' + @ShiftID + 
                                       ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                                       'Allowed punch-out window: ' + CONVERT(VARCHAR, @ValidPunchOutStart, 108) + 
                                       ' to ' + CONVERT(VARCHAR, @ValidPunchOutEnd, 108) + '.';
                    END
                    ELSE
                    BEGIN
                        SET @Message = @Message + 'Punch-Out at ' + CONVERT(VARCHAR, @PunchOutTime, 108) + 
                                       ' is invalid for ShiftID ' + @ShiftID + 
                                       ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                                       'Allowed punch-out window: ' + CONVERT(VARCHAR, @ValidPunchOutStart, 108) + 
                                       ' to ' + CONVERT(VARCHAR, @ValidPunchOutEnd, 108) + '.';
                    END;
                END
                ELSE
                BEGIN
                    SET @Message = @Message + 'Punch-Out not provided.';
                END;
            END
            ELSE
            BEGIN
                SET @Message = @Message + 'No applicable shift found for employee ' + @EmpCode + ' on date ' + CONVERT(VARCHAR, @PunchDate, 23) + '. ';
            END;
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'No shift details found for employee ' + @EmpCode + '. ';
        END;

        -- Location Validation
        IF @LocationDetailsJson IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM OPENJSON(@LocationDetailsJson)
                WITH (
                    LocationID INT,
                    georange VARCHAR(100),  -- Range in kilometers or other units
                    rangeinkm BIT,          -- Whether range is in kilometers (1) or not (0)
                    Latitude DECIMAL(10,7),
                    Longitude DECIMAL(10,7),
                    FromDate DATETIME,
                    ToDate DATETIME
                ) AS locations
                WHERE 
                    @PunchInDateTime BETWEEN FromDate AND ToDate
                    AND dbo.fn_CalculateDistance(
                        @Latitude, @Longitude, 
                        locations.Latitude, locations.Longitude
                    ) <= CAST(locations.georange AS DECIMAL(10,2)) * 
                        CASE WHEN locations.rangeinkm = 1 THEN 1000.0 ELSE 1.0 END  -- Convert km to meters if needed
            )
            BEGIN
                SET @IsValidLocation = 1;
                SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is valid at ' + CONVERT(VARCHAR, @PunchInDateTime, 120) + '. ';
            END
            ELSE
            BEGIN
                SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is invalid at ' + CONVERT(VARCHAR, @PunchInDateTime, 120) + '. ';
            END;
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'No location details found for employee ' + @EmpCode + '. ';
        END;
    END TRY
    BEGIN CATCH
        SET @Message = 'Error processing employee ' + @EmpCode + ': ' + ERROR_MESSAGE() + ' at line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + '. JSON snippet: ShiftDetails=' + LEFT(@ShiftDetailsJson, 100) + ', LocationDetails=' + LEFT(@LocationDetailsJson, 100);
        RETURN;
    END CATCH;

    -- Final combined validation message
    SET @Message = 'Validation Result - PunchIn: ' + CAST(@IsValidPunchIn AS VARCHAR(1)) + ', PunchOut: ' + CAST(@IsValidPunchOut AS VARCHAR(1)) + ', Location: ' + CAST(@IsValidLocation AS VARCHAR(1)) + '. ' + @Message;
END;
GO


DECLARE @IsValidPunchIn BIT, @IsValidPunchOut BIT, @IsValidLocation BIT, @Message VARCHAR(500);
EXEC dbo.ValidateEmployeePunchWithLocation
    @EmpCode = '00000003',
    @PunchInDateTime = '2022-01-23 07:50:00', -- Check against ShiftDetails
    @PunchOutDateTime = '2022-01-23 16:00:00',
    @Latitude = 28.4594965000, -- Matches LocationID 10013
    @Longitude = 77.0266383000,
    @IsValidPunchIn = @IsValidPunchIn OUTPUT,
    @IsValidPunchOut = @IsValidPunchOut OUTPUT,
    @IsValidLocation = @IsValidLocation OUTPUT,
    @Message = @Message OUTPUT;

SELECT 
    @IsValidPunchIn AS IsValidPunchIn, 
    @IsValidPunchOut AS IsValidPunchOut, 
    @IsValidLocation AS IsValidLocation, 
    @Message AS Message;
