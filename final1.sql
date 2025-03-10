create or alter PROCEDURE dbo.ValidateEmployeePunch
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

    -- Merged Location and IP Validation
    IF @LocationDetailsJson IS NOT NULL OR @IPRangeJson IS NOT NULL
    BEGIN
        DECLARE @LocationValid BIT = 0;
        DECLARE @IPValid BIT = 0;

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
                SET @LocationValid = 1;
            END
        END
        ELSE
        BEGIN
            SET @Message = @Message + 'No location details found for employee ' + @EmpCode + '. ';
        END;

        -- IP Validation
        IF @IPCheckEnabled = 'true' AND @IPRangeJson IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM OPENJSON(@IPRangeJson)
                WITH (
                    IPFrom VARCHAR(15),
                    IPTo VARCHAR(15)
                ) AS ipRanges
                WHERE dbo.fn_IsIPInRange(@ClientIPAddress, ipRanges.IPFrom, ipRanges.IPTo) = 1
            )
            BEGIN
                SET @IPValid = 1;
            END
        END
        ELSE IF @IPCheckEnabled = 'false'
        BEGIN
            SET @IPValid = 1; -- IP check is disabled, so consider it valid
            SET @Message = @Message + 'IP check is disabled for employee ' + @EmpCode + '. ';
        END
        ELSE IF @IPRangeJson IS NULL
        BEGIN
            SET @Message = @Message + 'No IP range details found for employee ' + @EmpCode + '. ';
        END;

        -- Set final outputs based on both validations
        SET @IsValidLocation = @LocationValid;
        SET @IsValidIP = @IPValid;

        -- Construct message
        IF @LocationValid = 1
            SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is valid at ' + CONVERT(VARCHAR, @PunchDateTime, 120) + '. ';
        ELSE
            SET @Message = @Message + 'Location (' + CAST(@Latitude AS VARCHAR(15)) + ', ' + CAST(@Longitude AS VARCHAR(15)) + ') is invalid at ' + CONVERT(VARCHAR, @PunchDateTime, 120) + '. ';

        IF @IPCheckEnabled = 'true'
        BEGIN
            IF @IPValid = 1
                SET @Message = @Message + 'IP address ' + @ClientIPAddress + ' is valid. ';
            ELSE
                SET @Message = @Message + 'IP address ' + @ClientIPAddress + ' is invalid. ';
        END
    END
    ELSE
    BEGIN
        SET @Message = @Message + 'No location or IP details found for employee ' + @EmpCode + '. ';
    END;
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
    @ClientIPAddress = '111.111.111.111', -- Example IP to validate
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










create or ALTER PROCEDURE dbo.ValidateEmployeePunch

    @EmpCode VARCHAR(100),
    @PunchDateTime DATETIME,           -- Single datetime for punch event
    @PunchIn BIT,                      -- 1 = Validate Punch-In, 0 = Ignore
    @PunchOut BIT,                     -- 1 = Validate Punch-Out, 0 = Ignore
    @IPAddress VARCHAR(50),             -- New parameter for IP validation
    @IsValidPunchIn BIT OUTPUT,
    @IsValidPunchOut BIT OUTPUT,
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
    DECLARE @IsIPValid BIT;
 
    -- Punch validation variables

    DECLARE @PunchTime TIME = CAST(@PunchDateTime AS TIME);
    DECLARE @PunchDate DATE = CAST(@PunchDateTime AS DATE);
 
    -- Initialize outputs

    SET @IsValidPunchIn = 0;
    SET @IsValidPunchOut = 0;
    SET @Message = '';
 
    -- Validate input: Only one of PunchIn or PunchOut should be 1

    IF (@PunchIn = 1 AND @PunchOut = 1) OR (@PunchIn = 0 AND @PunchOut = 0)
    BEGIN
        SET @Message = 'Invalid input: Specify either PunchIn = 1 or PunchOut = 1, but not both or neither.';
        RETURN;
    END;
 
    -- **Step 1: Validate Employee IP**

    EXEC dbo.CheckEmployeeIPValidation 
        @EmpCode = @EmpCode, 
        @IPAddress = @IPAddress, 
        @IsValid = @IsIPValid OUTPUT;
    IF @IsIPValid = 0
    BEGIN
        SET @Message = 'Punch rejected: Invalid IP address ' + @IPAddress + ' for employee ' + @EmpCode;
        RETURN;

    END;
 
    -- **Step 2: Get ShiftDetails JSON**
    SELECT @ShiftDetailsJson = ShiftDetails FROM dbo.FlatTable WHERE EmpCode = @EmpCode;
 
    IF @ShiftDetailsJson IS NULL
    BEGIN
        SET @Message = 'No shift details found for employee ' + @EmpCode;
        RETURN;
    END;
 
    IF ISJSON(@ShiftDetailsJson) = 0
    BEGIN
        SET @Message = 'Invalid JSON format in ShiftDetails for employee ' + @EmpCode + ': ' + LEFT(@ShiftDetailsJson, 100);
        RETURN;
    END;
 
    -- **Step 3: Parse JSON to Extract Shift Details**
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
                            AND CAST(JSON_VALUE(range.value, '$.RangeEnd') AS DATE)
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
 
    -- **Step 4: Compute Valid Punch Windows**
    DECLARE @ValidPunchInStart TIME = DATEADD(MINUTE, -@PreTime, @InTime);
    DECLARE @ValidPunchInEnd TIME = @InTime;
    DECLARE @ValidPunchOutStart TIME = @OutTime;
    DECLARE @ValidPunchOutEnd TIME = DATEADD(MINUTE, @PostTime, @OutTime);
 
    -- **Step 5: Validate Punch Timing**

    IF @PunchIn = 1

    BEGIN
        IF @PunchTime BETWEEN @ValidPunchInStart AND @ValidPunchInEnd
        BEGIN
            SET @IsValidPunchIn = 1;
            SET @Message = 'Punch-In at ' + CONVERT(VARCHAR, @PunchTime, 108) + 

                           ' is valid for ShiftID ' + @ShiftID;

        END
        ELSE
        BEGIN
            SET @Message = 'Invalid Punch-In time. Allowed: ' + 

                           CONVERT(VARCHAR, @ValidPunchInStart, 108) + 

                           ' to ' + CONVERT(VARCHAR, @ValidPunchInEnd, 108) + '.';

        END;
    END
    ELSE IF @PunchOut = 1
    BEGIN
        IF @PunchTime BETWEEN @ValidPunchOutStart AND @ValidPunchOutEnd
        BEGIN
            SET @IsValidPunchOut = 1;
            SET @Message = 'Punch-Out at ' + CONVERT(VARCHAR, @PunchTime, 108) + 

                           ' is valid for ShiftID ' + @ShiftID;
        END
        ELSE
        BEGIN
            SET @Message = 'Invalid Punch-Out time. Allowed: ' + 
                           CONVERT(VARCHAR, @ValidPunchOutStart, 108) + 
                           ' to ' + CONVERT(VARCHAR, @ValidPunchOutEnd, 108) + '.';
        END;
    END;
END;
GO
 
DECLARE @IsValidPunchIn BIT, @IsValidPunchOut BIT, @Message VARCHAR(500)
EXEC dbo.ValidateEmployeePunch
    @EmpCode = '00000003',
    @PunchDateTime = '2023-05-02 17:30:00',
    @PunchIn = 0,
    @PunchOut = 1,
    @IPAddress = '1.1.1.9', -- IP to validate
    @IsValidPunchIn = @IsValidPunchIn OUTPUT,
    @IsValidPunchOut = @IsValidPunchOut OUTPUT,
    @Message = @Message OUTPUT;
SELECT @IsValidPunchIn AS IsValidPunchIn, @IsValidPunchOut AS IsValidPunchOut, @Message AS Message;
 
 
