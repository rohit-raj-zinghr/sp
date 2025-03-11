---new final ones

CREATE OR ALTER PROCEDURE dbo.ValidateEmployeePunch
    @EmpCode VARCHAR(100),
    @PunchDateTime DATETIME,           -- Single datetime for punch event
    @Latitude DECIMAL(10,7),           -- Latitude of the punch location
    @Longitude DECIMAL(10,7),          -- Longitude of the punch location
    @ClientIPAddress VARCHAR(15),      -- Client IP address to validate
    @Source VARCHAR(50) = 'Mobile',    -- Source of punch (e.g., Mobile, Web)
    @AttMode INT = 1,                  -- Attendance mode (default BIO)
    @Type VARCHAR(10),                 -- 'PUNCHIN' or 'PUNCHOUT'
    @IsValidPunch BIT OUTPUT,          -- Single output for punch validity
    @IsValidLocation BIT OUTPUT,       -- Output for location validation
    @IsValidIP BIT OUTPUT,             -- Output for IP validation
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
    DECLARE @LocationDetailsJson NVARCHAR(MAX);
    DECLARE @IPRangeJson NVARCHAR(MAX);
    DECLARE @IPCheckEnabled VARCHAR(5);
    DECLARE @PunchTime TIME = CAST(@PunchDateTime AS TIME);
    DECLARE @PunchDate DATE = CAST(@PunchDateTime AS DATE);
    DECLARE @EmpIdentification VARCHAR(20);
    DECLARE @TimeZoneDiff INT = 0;
    DECLARE @CountryCode VARCHAR(50) = '';
    DECLARE @CreatedOn DATETIME = GETDATE();
    DECLARE @TermNo VARCHAR(10);
    DECLARE @ShiftStartDateTime DATETIME;
    DECLARE @ShiftEndDateTime DATETIME;
    DECLARE @ShiftWithPre DATETIME;
    DECLARE @ShiftWithPost DATETIME;

    -- Initialize outputs
    SET @IsValidPunch = 0;
    SET @IsValidLocation = 0;
    SET @IsValidIP = 0;
    SET @Message = '';

    -- Validate @Type parameter
    IF UPPER(@Type) NOT IN ('PUNCHIN', 'PUNCHOUT')
    BEGIN
        SET @Message = 'Invalid @Type parameter. Must be PUNCHIN or PUNCHOUT';
        RETURN;
    END;

    -- Fetch timezone and country code
    SELECT @TimeZoneDiff = TimezoneDiff, @CountryCode = CountryCode
    FROM EmployeeAttributeDetails D
    INNER JOIN AttributeTypeMaster AT ON D.AttributeTypeId = AT.AttributeTypeId 
        AND AttributeTypeDescription = 'Country' 
        AND D.ToDate IS NULL
    INNER JOIN AttributeTypeUnitMaster AUT ON D.AttributeTypeUnitID = AUT.AttributeTypeUnitID
    INNER JOIN [Common].[TimeZoneMaster] TZM ON TZM.CountryDesc = AUT.AttributeTypeUnitDescription
    WHERE EmployeeCode = @EmpCode;

    -- Adjust PunchDateTime for user's timezone
    SET @PunchDateTime = DATEADD(MI, ISNULL(@TimeZoneDiff, 0), @PunchDateTime);
    SET @PunchTime = CAST(@PunchDateTime AS TIME); -- Recalculate after adjustment

    -- Get Employee Identification
    SELECT @EmpIdentification = EmpIdentification
    FROM TNA.EmpIdentityCodeMap
    WHERE Empcode = @EmpCode;

    IF @EmpIdentification IS NULL
    BEGIN
        SET @Message = 'Employee identification not found for EmpCode ' + @EmpCode;
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

    IF @ShiftDetailsJson IS NULL
    BEGIN
        SET @Message = 'No shift details found for employee ' + @EmpCode;
        RETURN;
    END;

    -- JSON validation
    IF ISJSON(@ShiftDetailsJson) = 0
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

    -- Parse ShiftDetails JSON
    BEGIN TRY
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
            SET @Message = 'No applicable shift found for employee ' + @EmpCode + ' on date ' + CONVERT(VARCHAR, @PunchDate, 23);
            RETURN;
        END;
    END TRY
    BEGIN CATCH
        SET @Message = 'Error parsing JSON for employee ' + @EmpCode + ': ' + ERROR_MESSAGE();
        RETURN;
    END CATCH;

    -- Calculate shift window
    SET @ShiftStartDateTime = CAST(CAST(@PunchDate AS DATE) AS DATETIME) + CAST(@InTime AS DATETIME);
    SET @ShiftEndDateTime = CAST(CAST(@PunchDate AS DATE) AS DATETIME) + CAST(@OutTime AS DATETIME);
    SET @ShiftWithPre = DATEADD(MINUTE, -@PreTime, @ShiftStartDateTime);
    SET @ShiftWithPost = DATEADD(MINUTE, @PostTime, @ShiftEndDateTime);

    -- Set TermNo based on @Type
    SET @TermNo = CASE UPPER(@Type) WHEN 'PUNCHIN' THEN 'Punch IN' WHEN 'PUNCHOUT' THEN 'Punch Out' END;

    -- Punch-In/Punch-Out Logic
    IF UPPER(@Type) = 'PUNCHIN'
    BEGIN
        -- Check if punch is within shift timing window
        IF @PunchDateTime < @ShiftWithPre OR @PunchDateTime > @ShiftWithPost
        BEGIN
            SET @Message = 'You are not allowed to punch in outside your shift timings: ' + 
                          CONVERT(VARCHAR, @ShiftWithPre, 120) + ' to ' + CONVERT(VARCHAR, @ShiftWithPost, 120);
            RETURN;
        END;

        -- Check for existing Punch-In
        IF EXISTS (
            SELECT 1 FROM TNA.SwipeData 
            WHERE AttMode = @AttMode 
            AND EmpIdentification = @EmpIdentification 
            AND TermNo = 'Punch IN' 
            AND SwipeDate BETWEEN @ShiftWithPre AND @ShiftWithPost
        )
        BEGIN
            SET @Message = 'Punch-In is already done!';
            RETURN;
        END;

        SET @IsValidPunch = 1; -- Valid if timing and no duplicate
    END
    ELSE IF UPPER(@Type) = 'PUNCHOUT'
    BEGIN
        -- Check if Punch-In exists
        IF NOT EXISTS (
            SELECT 1 FROM TNA.SwipeData 
            WHERE EmpIdentification = @EmpIdentification 
            AND SwipeDate BETWEEN @ShiftWithPre AND @ShiftWithPost
            AND TermNo = 'Punch IN'
        )
        BEGIN
            SET @Message = 'Punch-In not yet done!';
            RETURN;
        END;

        -- Check if punch is within shift timing window
        IF @PunchDateTime < @ShiftWithPre OR @PunchDateTime > @ShiftWithPost
        BEGIN
            SET @Message = 'You are not allowed to punch out outside your shift timings: ' + 
                          CONVERT(VARCHAR, @ShiftWithPre, 120) + ' to ' + CONVERT(VARCHAR, @ShiftWithPost, 120);
            RETURN;
        END;

        -- **Modification**: Allow duplicate punch-outs
        -- Instead of rejecting duplicates, we will log them with a note in the message
        IF EXISTS (
            SELECT 1 FROM TNA.SwipeData 
            WHERE AttMode = @AttMode 
            AND EmpIdentification = @EmpIdentification 
            AND TermNo = 'Punch Out' 
            AND SwipeDate BETWEEN @ShiftWithPre AND @ShiftWithPost
        )
        BEGIN
            SET @Message = 'Duplicate Punch-Out detected, but it will be logged.';
            -- Continue with logging the punch-out instead of returning
        END;

        SET @IsValidPunch = 1; -- Valid if timing and Punch-In exists
    END;

    -- Location Validation
    IF @LocationDetailsJson IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@LocationDetailsJson)
            WITH (
                LocationID INT,
                georange VARCHAR(100),
                rangeinkm BIT,
                Latitude DECIMAL(10,7),
                Longitude DECIMAL(10,7),
                FromDate DATETIME,
                ToDate DATETIME
            ) AS locations
            WHERE 
                @PunchDateTime BETWEEN FromDate AND ToDate
                AND dbo.fn_CalculateDistance(@Latitude, @Longitude, locations.Latitude, locations.Longitude) <= 
                    CAST(locations.georange AS DECIMAL(10,2)) * CASE WHEN locations.rangeinkm = 1 THEN 1000.0 ELSE 1.0 END
        )
            SET @IsValidLocation = 1;
        ELSE
        BEGIN
            SET @Message = 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is invalid.';
            RETURN;
        END;
    END
    ELSE
    BEGIN
        SET @IsValidLocation = 1; -- Assume valid if no location details
        SET @Message = @Message + 'No location details found, assuming valid. ';
    END;

    -- IP Validation
    IF @IPCheckEnabled != 'false'
    BEGIN
        DECLARE @IPRangesDB NVARCHAR(MAX);
        SELECT @IPRangesDB = (
            SELECT IPFrom, IPTo
            FROM GeoConfig.GeoConfigurationIPMaster geoip  
            WHERE geoip.GeoConfigurationID IN (
                SELECT DISTINCT gl_sub.ID
                FROM GeoConfig.GeoConfigurationLocationMst gl_sub
                INNER JOIN GeoConfig.EmployeesLocationMapping gg_sub
                    ON gl_sub.ID = gg_sub.LocationID
                WHERE gg_sub.EmployeeCode = @EmpCode
            )
            FOR JSON PATH
        );

        DECLARE @FinalIPRangeJson NVARCHAR(MAX) = COALESCE(@IPRangesDB, @IPRangeJson);
        IF @FinalIPRangeJson IS NOT NULL AND @FinalIPRangeJson != '[]'
        BEGIN
            CREATE TABLE #IPRanges (IPFrom VARCHAR(20), IPTo VARCHAR(20));
            INSERT INTO #IPRanges (IPFrom, IPTo)
            SELECT IPFrom, IPTo
            FROM OPENJSON(@FinalIPRangeJson)
            WITH (IPFrom VARCHAR(20) '$.IPFrom', IPTo VARCHAR(20) '$.IPTo');

            IF EXISTS (SELECT 1 FROM #IPRanges WHERE dbo.IsIPAddressInRange(@ClientIPAddress, IPFrom, IPTo) = 1)
                SET @IsValidIP = 1;
            ELSE
            BEGIN
                SET @Message = 'IP address ' + @ClientIPAddress + ' is invalid.';
                DROP TABLE #IPRanges;
                RETURN;
            END;
            DROP TABLE #IPRanges;
        END
        ELSE
        BEGIN
            SET @Message = 'No IP ranges found for employee ' + @EmpCode + '.';
            RETURN;
        END;
    END
    ELSE
    BEGIN
        SET @IsValidIP = 1; -- Assume valid if IP check is disabled
        SET @Message = @Message + 'IP check disabled, assuming valid. ';
    END;

    -- Store Punch Data if all validations pass
    IF @IsValidPunch = 1 AND @IsValidLocation = 1 AND @IsValidIP = 1
    BEGIN
        BEGIN TRY
            -- Insert into SwipeData
            INSERT INTO TNA.SwipeData 
                (AttMode, EmpIdentification, TermNo, SwipeDate, TimeZone, Createdon, CreatedBy, UpdatedOn, UpdatedBy, IpAddress, Source)
            VALUES 
                (@AttMode, @EmpIdentification, @TermNo, @PunchDateTime, @TimeZoneDiff, @CreatedOn, @EmpCode, 
                 @CreatedOn, @TermNo + '-' + ISNULL(@CountryCode, ''), @ClientIPAddress, @Source);

            -- Insert into PUNCHIN_LOCATION
            INSERT INTO TNA.PUNCHIN_LOCATION 
                (EMPIDENTIFICATION, SWIPEDATE, IPADDRESS, PUNCHINOUTACTION, USERID, Latitude, Longitude, Source)
            VALUES 
                (@EmpIdentification, @PunchDateTime, @ClientIPAddress, UPPER(@TermNo), @EmpCode, @Latitude, @Longitude, @Source);

            SET @Message = 'You have ' + 
                          CASE UPPER(@Type) WHEN 'PUNCHIN' THEN 'punched in' WHEN 'PUNCHOUT' THEN 'punched out' END + 
                          ' successfully at ' + CONVERT(VARCHAR, @PunchDateTime, 120);
        END TRY
        BEGIN CATCH
            SET @Message = 'Error inserting punch data: ' + ERROR_MESSAGE();
            SET @IsValidPunch = 0;
            RETURN;
        END CATCH;
    END
    ELSE
    BEGIN
        SET @Message = @Message + 'Punch failed due to validation errors.';
    END;
END;
GO

-- Example execution
DECLARE @IsValidPunch BIT, @IsValidLocation BIT, @IsValidIP BIT, @Message VARCHAR(500);
EXEC dbo.ValidateEmployeePunch
    @EmpCode = 'admin',
    @PunchDateTime = '2025-03-14 16:00:00',
    @Latitude = 19.533572,
    @Longitude = 78.877306,
    @ClientIPAddress = '192.168.1.190',
    @Source = 'Mobile',
    @AttMode = 1,
    @Type = 'PUNCHOUT',  -- Specify PUNCHIN or PUNCHOUT
    @IsValidPunch = @IsValidPunch OUTPUT,
    @IsValidLocation = @IsValidLocation OUTPUT,
    @IsValidIP = @IsValidIP OUTPUT,
    @Message = @Message OUTPUT;
SELECT @IsValidPunch AS IsValidPunch, @IsValidLocation AS IsValidLocation, @IsValidIP AS IsValidIP, @Message AS Message;

DELETE FROM tna.SwipeData
WHERE SwipeDate BETWEEN '2025-03-11 00:00:00' AND '2025-03-16 23:59:59';


select  top 20* from tna.PUNCHIN_LOCATION order by SwipeDate desc;
select  top 6* from tna.SwipeData order by SwipeDate desc;
