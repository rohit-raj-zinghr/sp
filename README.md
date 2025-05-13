<a name="readme-top"></a>

### Project Overview

The Real-Time Attendance (TNA) system  designed to streamline and automate employee attendance processing. The system utilizes a series of SQL stored procedures to:





i) Manage Shift Rules: Define and apply rules for overtime and shift-specific calculations.



ii) Track Attendance Metrics: Monitor punch-in and punch-out times, ensuring accurate attendance records.



iii) Calculate Compliance: Validate late arrivals and early departures against predefined grace periods.



iv) Update Records: Maintain up-to-date attendance data in the Rostering table, including metrics like overtime and attendance results.

## Cool features of TNA

- 🆕 [**Automated Attendance Processing:Eliminates manual tracking with real-time calculations.**]
- 🆕 [**Overtime Management:Calculates PreOT, PostOT, and other overtime metrics based on shift and day type.**]
- 🆕 [**Grace Period Validation:Tracks allowable instances of late arrivals and early departures.**]


**Real Time Attendance(TNA) Steps:**

- Step1:[ Create and execute the stored procedure TNA.SetExtraTimeRule_Z2 ](https://github.com/zinghrcore/z2-tna-db/blob/master/SetExtraTimeRule_Z2)
- Step2:[Set the database compatibility level to 150.](https://github.com/zinghrcore/z2-tna-db/blob/master/Compatibility%20Level)
- Step3:[If not exist,Add DayType Column in Rostering](https://github.com/zinghrcore/z2-tna-db/blob/master/add%20column%20daytype)
- Step4:[Create table TNA.ShiftWithPrePost](https://github.com/zinghrcore/z2-tna-db/blob/master/Create%20table%20SHIFTWITHPREPOST)
- Step5:[For FlatTable Population create SP  TNA. Setempshiftjson ](https://github.com/zinghrcore/z2-tna-db/blob/master/Flattable%20Population.sql)
- Step6:[Create stored procedure  TNA.LateComingCalculationOnPunchOut_Z2 ](https://github.com/zinghrcore/z2-tna-db/blob/master/LateComingCalculationOnPunchOut_Z2.sql)
- Step7:[Create stored procedure  TNA.EarlygoingCalculationOnPunchOut_Z2 ](https://github.com/zinghrcore/z2-tna-db/blob/master/EarlyGoingCalculationOnPunchOut.sql)
- Step8:[Create stored procedure  PunchInOnLogin ](https://github.com/zinghrcore/z2-tna-db/blob/master/%5BTNA%5D.%5BPunchInOnLogin%5D.sql)
- Step9:[Create stored procedure   PunchInOnThroughBio_z2 ](https://github.com/zinghrcore/z2-tna-db/blob/master/PunchInOnThroughBio_z2.sql)



# 🕒 BackDated Attendance Process - TNA System

This guide outlines the sequential process for executing **BackDated Attendance updation** in the **Time and Attendance (TNA)** system.

## 📌 Job Reference  
**Job Name:** `Attendance_job_for_cowayqa5`  
**Objective:** To process and finalize backdated attendance records, ensuring rule compliance and data readiness for reporting.
### ✅ Step 1:[Generate the FlatTable required for backdated data processing.](https://github.com/zinghrcore/z2-tna-db/blob/master/1.setempshiftjsondata.sql)
### ✅ Step 2:[Create FILO (First In Last Out) attendance records from the JSON shift data](https://github.com/zinghrcore/z2-tna-db/blob/master/2.FiloCreationWithJSON_Z2.sql)
### ✅ Step 3:[Apply Working Hours Rule by creating sp [TNA].[AttendanceRule_WorkingHrs]](https://github.com/zinghrcore/z2-tna-db/blob/master/3.AttendanceRule_WorkingHrs.sql)
### ✅ Step 4:[Apply Late Coming Rule using sp ATTENDANCERULE_LATECOMING](https://github.com/zinghrcore/z2-tna-db/blob/master/4.ATTENDANCERULE_LATECOMING.sql)
### ✅ Step 5:[Apply Late Coming Rule using sp ATTENDANCERULE_EARLYGOING](https://github.com/zinghrcore/z2-tna-db/blob/master/5.ATTENDANCERULE_EARLYGOING.sql)
### ✅ Step 6:[Apply Flexitime Rule using sp ATTENDANCERULE_FLEXITIME](https://github.com/zinghrcore/z2-tna-db/blob/master/6.ATTENDANCERULE_FLEXITIME.sql)
### ✅ Step 7:[Process BackDated Extra Time using sp GenExtraTimeZ2_AttProcess](https://github.com/zinghrcore/z2-tna-db/blob/master/7.GenExtraTimeZ2_AttProcess.sql)
### ✅ Step 8:[Apply Compensatory Off Rule usinf sp ATTENDANCERULE_COMPOFF](https://github.com/zinghrcore/z2-tna-db/blob/master/8.ATTENDANCERULE_COMPOFF.sql)
### ✅ Step 9:[Handle Attendance Exceptions using sp ATTENDANCERULE_EXCEPTIONS](https://github.com/zinghrcore/z2-tna-db/blob/master/9.ATTENDANCERULE_EXCEPTIONS.sql)
### ✅ Step 10:[ Display Attendance Results using sp AttendanceRule_DisplayResult](https://github.com/zinghrcore/z2-tna-db/blob/master/10.AttendanceRule_DisplayResult.sql)
### ✅ Step 11:[Transfer Data for Reports using sp DataTransferForReports](https://github.com/zinghrcore/z2-tna-db/blob/master/11.DataTransferForReports.sql)




## 🌟 Contributors
<div style="text-align: center;">
  <h2>🌟 Contributors</h2>
  <div style="display: flex; flex-wrap: wrap; justify-content: space-around; width: 100%;">
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/prasad-rajappan-a002a73/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/C4E03AQEQl64iTddLkw/profile-displayphoto-shrink_400_400/profile-displayphoto-shrink_400_400/0/1516298618284?e=1751500800&v=beta&t=QZ-WYMxK5vPV-_iFCikorpW6VSIWnhWAz7LlXiX5LXE" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 1"/>
        <br/>
        <sub><b>Prasad Rajappan</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/nikhil004/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQGys4LpBZOvng/profile-displayphoto-shrink_200_200/profile-displayphoto-shrink_200_200/0/1726168691780?e=2147483647&v=beta&t=7_LfxXThuPlIpSHmiPCQe1bwPCkJW52oAVhJOn5FL0E" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 2"/>
        <br/>
        <sub><b>Nikhil Mishra</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/hemant-meena-208b2556/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQE7YLjE5a77dg/profile-displayphoto-shrink_400_400/B4DZXlkzApHsAg-/0/1743313384104?e=1751500800&v=beta&t=fMEISdFGYxEw5J4Wnki5WaBSIIsz9yD4aHsmx0F3Bq8" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 3"/>
        <br/>
        <sub><b>Hemant Meena</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/mihir-mistry-93068b223/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQEpLW8pg6DVgw/profile-displayphoto-shrink_200_200/B4DZRrVZvRHcAg-/0/1736967562482?e=2147483647&v=beta&t=HrPYZoofkqgqDIfavB3QjqSbbWQPP4aza3LomSTXoGk" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 4"/>
        <br/>
        <sub><b>Mihir Mistry</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/amol-dingankar-315459121/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQHvWF1_C18zxw/profile-displayphoto-shrink_400_400/profile-displayphoto-shrink_400_400/0/1670330113667?e=1751500800&v=beta&t=5OHQubiCZG5QdtQSh6AiQinKHsmllf0XGrw2baotTsk" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 5"/>
        <br/>
        <sub><b>Amol Dingankar</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/omveer-singh-82102a29/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D5603AQEAaLfXazpQeA/profile-displayphoto-shrink_400_400/profile-displayphoto-shrink_400_400/0/1714208348267?e=1751500800&v=beta&t=l5QotBO0eGPa5Nman6hlqQu6A5xPoVjMbPn8Ua6Ac84" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 6"/>
        <br/>
        <sub><b>Omveer Singh</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/vijay-boura-b1197517a/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D5603AQFFl0UQvFIiuw/profile-displayphoto-shrink_400_400/B56ZaQunylHsAg-/0/1746184866189?e=1751500800&v=beta&t=-oPo7evoLYQwDDSuPYLHlfmqTAnQVLJu5R1B8nRLgJo" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 7"/>
        <br/>
        <sub><b>Vijay Boura</b></sub>
      </a>
    </div>
    <div style="flex: 1 1 20%; text-align: center; margin: 10px 0;">
      <a href="https://www.linkedin.com/in/imrohi8/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D5603AQG5hOhdd_j3xg/profile-displayphoto-shrink_400_400/B56ZUkf5m7HQAg-/0/1740074097527?e=1751500800&v=beta&t=iqR0a0HtngiLptIxvEXP_RgpWKXA9ve43hkXS1_Bw8g" style="max-width: 100%; height: auto; border-radius: 50%;" alt="Contributor 8"/>
        <br/>
        <sub><b>Rohit Raj</b></sub>
      </a>
    </div>
  </div>
</div>






## Resources

- [Detailed Report](https://zinghr365-my.sharepoint.com/:w:/g/personal/nikhil_mishra_zinghr_com/EQtXlIN-tVFKks0tMhePZmEBjwJWUVPBQbnlyqqT4rnOJQ?wdOrigin=TEAMS-MAGLEV.undefined_ns.rwc&wdExp=TEAMS-TREATMENT&wdhostclicktime=1746181572438&web=1)
- [Steps Report](https://drive.google.com/file/d/1VrXBYQQknR33bqLG-Che7I3bnBFKTl6T/view?usp=drive_link)
- [All Tables and Stored Procedures](https://github.com/zinghrcore/z2-tna-db/blob/master/Final%20SP%20and%20tables.rar)

[![][back-to-top]](#readme-top)

Copyright © 2025[ZingHR](https://www.zinghr.com/)  <br />









