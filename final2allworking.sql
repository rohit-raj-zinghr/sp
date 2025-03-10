CREATE OR ALTER PROCEDURE dbo.ValidateEmployeePunch
    @EmpCode VARCHAR(100),
    @PunchDateTime DATETIME,           -- Single datetime for punch event
    @PunchIn BIT,                      -- 1 = Validate Punch-In, 0 = Ignore
    @PunchOut BIT,                     -- 1 = Validate Punch-Out, 0 = Ignore
    @Latitude DECIMAL(10,7),           -- Latitude of the punch location
    @Longitude DECIMAL(10,7),          -- Longitude of the punch location
    @ClientIPAddress VARCHAR(15),      -- Client IP address to validate
    @IsValidPunchIn BIT OUTPUT,
    @IsValidPunchOut BIT OUTPUT,
    @IsValidLocation BIT OUTPUT,       -- New output for location validation
    @IsValidIP BIT OUTPUT,             -- New output for IP validation
    @Message VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables
    DECLARE @ShiftID VARCHAR(50);
    DECLARE @InTime TIME;
    DECLARE @OutTime TIME;
    DECLARE @PreTime INT;
    DECLARE @PostTime INT;
    DECLARE @ShiftStartDate DATE;
    DECLARE @ShiftEndDate DATE;
    DECLARE @ShiftDetailsJson NVARCHAR(MAX);

    -- Declare variables for location and IP validation
    DECLARE @LocationDetailsJson NVARCHAR(MAX);
    DECLARE @IPRangeJson NVARCHAR(MAX);
    DECLARE @IPCheckEnabled VARCHAR(5);

    -- Punch validation variables
    DECLARE @PunchTime TIME = CAST(@PunchDateTime AS TIME);
    DECLARE @PunchDate DATE = CAST(@PunchDateTime AS DATE);

    -- Initialize outputs
    SET @IsValidPunchIn = 0;
    SET @IsValidPunchOut = 0;
    SET @IsValidLocation = 0;
    SET @IsValidIP = 0;
    SET @Message = '';

    -- Validate input: Only one of PunchIn or PunchOut should be 1
    IF (@PunchIn = 1 AND @PunchOut = 1) OR (@PunchIn = 0 AND @PunchOut = 0)
    BEGIN
        SET @Message = 'Invalid input: Specify either PunchIn = 1 or PunchOut = 1, but not both or neither.';
        RETURN;
    END;

    -- Get ShiftDetails, LocationDetails, IPRange, and IPCheckEnabled JSON
    SELECT 
        @ShiftDetailsJson = ShiftDetails,
        @LocationDetailsJson = LocationDetails,
        @IPRangeJson = IPRange,
        @IPCheckEnabled = IPCheckEnabled
    FROM dbo.FlatTable
    WHERE EmpCode = @EmpCode;

    IF @ShiftDetailsJson IS NULL AND @LocationDetailsJson IS NULL AND @IPRangeJson IS NULL
    BEGIN
        SET @Message = 'No shift, location, or IP details found for employee ' + @EmpCode;
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

    IF @IPRangeJson IS NOT NULL AND ISJSON(@IPRangeJson) = 0
    BEGIN
        SET @Message = 'Invalid JSON format in IPRange for employee ' + @EmpCode + ': ' + LEFT(@IPRangeJson, 100);
        RETURN;
    END;

    -- Parse the JSON with detailed error handling
    BEGIN TRY
        -- Select the first matching shift based on date range
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

        IF @ShiftID IS NULL
        BEGIN
            SET @Message = 'No applicable shift found for employee ' + @EmpCode + ' on date ' + CONVERT(VARCHAR, @PunchDate, 23) + '. JSON snippet: ' + LEFT(@ShiftDetailsJson, 100);
            RETURN;
        END;
    END TRY
    BEGIN CATCH
        SET @Message = 'Error parsing JSON for employee ' + @EmpCode + ': ' + ERROR_MESSAGE() + ' at line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + '. JSON snippet: ' + LEFT(@ShiftDetailsJson, 100);
        RETURN;
    END CATCH;

    -- Calculate valid punch windows
    DECLARE @ValidPunchInStart TIME = DATEADD(MINUTE, -@PreTime, @InTime);
    DECLARE @ValidPunchInEnd TIME = @InTime;
    DECLARE @ValidPunchOutStart TIME = @OutTime;
    DECLARE @ValidPunchOutEnd TIME = DATEADD(MINUTE, @PostTime, @OutTime);

    -- Validate based on PunchIn or PunchOut flag
    IF @PunchIn = 1
    BEGIN
        IF @PunchTime BETWEEN @ValidPunchInStart AND @ValidPunchInEnd
        BEGIN
            SET @IsValidPunchIn = 1;
            SET @Message = @Message + 'Punch-In at ' + CONVERT(VARCHAR, @PunchTime, 108) + 
                           ' is valid for ShiftID ' + @ShiftID + 
                           ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                           'Allowed punch-in window: ' + CONVERT(VARCHAR, @ValidPunchInStart, 108) + 
                           ' to ' + CONVERT(VARCHAR, @ValidPunchInEnd, 108) + '. ';
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'Punch-In at ' + CONVERT(VARCHAR, @PunchTime, 108) + 
                           ' is invalid for ShiftID ' + @ShiftID + 
                           ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                           'Allowed punch-in window: ' + CONVERT(VARCHAR, @ValidPunchInStart, 108) + 
                           ' to ' + CONVERT(VARCHAR, @ValidPunchInEnd, 108) + '. ';
        END;
    END
    ELSE IF @PunchOut = 1
    BEGIN
        IF @PunchTime BETWEEN @ValidPunchOutStart AND @ValidPunchOutEnd
        BEGIN
            SET @IsValidPunchOut = 1;
            SET @Message = @Message + 'Punch-Out at ' + CONVERT(VARCHAR, @PunchTime, 108) + 
                           ' is valid for ShiftID ' + @ShiftID + 
                           ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                           'Allowed punch-out window: ' + CONVERT(VARCHAR, @ValidPunchOutStart, 108) + 
                           ' to ' + CONVERT(VARCHAR, @ValidPunchOutEnd, 108) + '. ';
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'Punch-Out at ' + CONVERT(VARCHAR, @PunchTime, 108) + 
                           ' is invalid for ShiftID ' + @ShiftID + 
                           ' (Range: ' + CONVERT(VARCHAR, @ShiftStartDate, 23) + ' to ' + CONVERT(VARCHAR, @ShiftEndDate, 23) + '). ' +
                           'Allowed punch-out window: ' + CONVERT(VARCHAR, @ValidPunchOutStart, 108) + 
                           ' to ' + CONVERT(VARCHAR, @ValidPunchOutEnd, 108) + '. ';
        END;
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
                @PunchDateTime BETWEEN FromDate AND ToDate
                AND dbo.fn_CalculateDistance(
                    @Latitude, @Longitude, 
                    locations.Latitude, locations.Longitude
                ) <= CAST(locations.georange AS DECIMAL(10,2)) * 
                    CASE WHEN locations.rangeinkm = 1 THEN 1000.0 ELSE 1.0 END  -- Convert km to meters if needed
        )
        BEGIN
            SET @IsValidLocation = 1;
            SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is valid at ' + CONVERT(VARCHAR, @PunchDateTime, 120) + '. ';
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is invalid at ' + CONVERT(VARCHAR, @PunchDateTime, 120) + '. ';
        END
    END
    ELSE
    BEGIN
        SET @Message = @Message + 'No location details found for employee ' + @EmpCode + '. ';
    END;

    -- IP Validation (integrated from CheckEmployeeIPValidation)
    -- First check if IP check is enabled
    DECLARE @IPCheckEnabledDB VARCHAR(5);
    
    -- Get IP check enabled status from the employee details
    SELECT @IPCheckEnabledDB = gc_bool.IPCheckEnabled
    FROM reqrec_employeedetails AS re
    INNER JOIN dbo.SETUP_EMPLOYEESTATUSMST AS se 
        ON re.ED_Status = se.ESM_EmpStatusID
    CROSS APPLY (
        SELECT 
            CASE WHEN MAX(CAST(gl.IPCheckEnabled AS INT)) = 1 THEN 'true' ELSE 'false' END AS IPCheckEnabled
        FROM GeoConfig.GeoConfigurationLocationMst gl
        INNER JOIN GeoConfig.EmployeesLocationMapping el 
            ON gl.ID = el.LocationId
        WHERE el.EmployeeCode = re.ed_empcode
    ) AS gc_bool
    WHERE re.ed_empcode = @EmpCode;

    -- Use local variable if available, otherwise fallback to the one from FlatTable
    IF @IPCheckEnabledDB IS NOT NULL
    BEGIN
        SET @IPCheckEnabled = @IPCheckEnabledDB;
    END

    -- If IP check is not enabled, consider it valid
    IF @IPCheckEnabled = 'false'
    BEGIN
        SET @IsValidIP = 1;
        SET @Message = @Message + 'IP check is disabled for employee ' + @EmpCode + '. ';
    END
    ELSE
    BEGIN
        -- For robust IP validation, get IP ranges directly from the source tables
        DECLARE @IPRangesDB NVARCHAR(MAX);
        
        -- Get the IP ranges for the employee directly from the source table
        SELECT @IPRangesDB = (
            SELECT 
                geoip.IPFrom,
                geoip.IPTo
            FROM GeoConfig.GeoConfigurationIPMaster geoip  
            WHERE geoip.GeoConfigurationID IN 
            (
                SELECT DISTINCT gl_sub.ID
                FROM GeoConfig.GeoConfigurationLocationMst gl_sub
                INNER JOIN GeoConfig.EmployeesLocationMapping gg_sub
                    ON gl_sub.ID = gg_sub.LocationID
                WHERE gg_sub.EmployeeCode = @EmpCode
            )
            FOR JSON PATH
        );

        -- Use direct DB values if available, otherwise fallback to the one from FlatTable
        DECLARE @FinalIPRangeJson NVARCHAR(MAX);
        IF @IPRangesDB IS NOT NULL AND @IPRangesDB <> '[]'
        BEGIN
            SET @FinalIPRangeJson = @IPRangesDB;
        END
        ELSE
        BEGIN
            SET @FinalIPRangeJson = @IPRangeJson;
        END

        -- If we don't have IP ranges, consider it invalid
        IF @FinalIPRangeJson IS NULL OR @FinalIPRangeJson = '[]'
        BEGIN
            SET @IsValidIP = 0;
            SET @Message = @Message + 'No IP ranges found for employee ' + @EmpCode + '. ';
        END
        ELSE
        BEGIN
            -- Create a temporary table to hold the IP ranges from JSON
            CREATE TABLE #IPRanges (
                IPFrom VARCHAR(20),
                IPTo VARCHAR(20)
            );
            
            -- Parse the JSON and insert into temp table
            INSERT INTO #IPRanges (IPFrom, IPTo)
            SELECT IPFrom, IPTo
            FROM OPENJSON(@FinalIPRangeJson)
            WITH (
                IPFrom VARCHAR(20) '$.IPFrom',
                IPTo VARCHAR(20) '$.IPTo'
            );
            DECLARE @IsIPValid BIT = 0;    -- Check if the provided IP address is within any of the allowed ranges
            SELECT @IsIPValid = MAX(dbo.IsIPAddressInRange(@ClientIPAddress, IPFrom, IPTo))
            FROM #IPRanges;
            SET @IsValidIP = ISNULL(@IsIPValid, 0); -- Set the output parameter
            IF @IsValidIP = 1    -- Append message
                SET @Message = @Message + 'IP address ' + @ClientIPAddress + ' is valid. ';
            ELSE
                SET @Message = @Message + 'IP address ' + @ClientIPAddress + ' is invalid. ';
            DROP TABLE #IPRanges;  -- Clean up
        END
    END
END;
GO



DECLARE @IsValidPunchIn BIT, @IsValidPunchOut BIT, @IsValidLocation BIT, @IsValidIP BIT, @Message VARCHAR(500);
EXEC dbo.ValidateEmployeePunch
    @EmpCode = '00000003',
    @PunchDateTime = '2023-05-02 09:00:00',
    @PunchIn = 1,
    @PunchOut = 0,
    @Latitude = 28.4594965000,
    @Longitude = 77.0266383000,
    @ClientIPAddress = '1.1.1.1', -- Example IP to validate
    @IsValidPunchIn = @IsValidPunchIn OUTPUT,
    @IsValidPunchOut = @IsValidPunchOut OUTPUT,
    @IsValidLocation = @IsValidLocation OUTPUT,
    @IsValidIP = @IsValidIP OUTPUT,
    @Message = @Message OUTPUT;

SELECT 
    @IsValidPunchIn AS IsValidPunchIn, 
    @IsValidPunchOut AS IsValidPunchOut, 
    @IsValidLocation AS IsValidLocation, 
    @IsValidIP AS IsValidIP,
    @Message AS Message;
