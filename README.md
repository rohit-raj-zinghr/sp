<a name="readme-top"></a>

# Real-Time Attendance (TNA) System

The Real-Time Attendance (TNA) system is designed to streamline and automate employee attendance processing. It utilizes a series of SQL stored procedures to:

1. **Manage Shift Rules:** Define and apply rules for overtime and shift-specific calculations.  
2. **Track Attendance Metrics:** Monitor punch-in/out times for accurate records.  
3. **Calculate Compliance:** Validate late arrivals and early departures.  
4. **Update Records:** Keep attendance and overtime data updated in the Rostering table.

---

## 🚀 Cool Features of TNA

- 🆕 **Automated Attendance Processing:** Eliminates manual tracking with real-time calculations.
- 🆕 **Overtime Management:** Calculates PreOT, PostOT, and related metrics.
- 🆕 **Grace Period Validation:** Tracks late arrivals and early exits with grace limits.

---

## 🔧 Real-Time TNA Setup Steps

- **Step 1:** [Create and execute the SP `TNA.SetExtraTimeRule_Z2`](https://github.com/zinghrcore/z2-tna-db/blob/master/SetExtraTimeRule_Z2)
- **Step 2:** [Set the database compatibility level to 150](https://github.com/zinghrcore/z2-tna-db/blob/master/Compatibility%20Level)
- **Step 3:** [Add DayType column in Rostering (if not exists)](https://github.com/zinghrcore/z2-tna-db/blob/master/add%20column%20daytype)
- **Step 4:** [Create table `TNA.ShiftWithPrePost`](https://github.com/zinghrcore/z2-tna-db/blob/master/Create%20table%20SHIFTWITHPREPOST)
- **Step 5:** [Create SP for FlatTable Population `TNA.SetEmpShiftJSON`](https://github.com/zinghrcore/z2-tna-db/blob/master/Flattable%20Population.sql)
- **Step 6:** [Create SP `TNA.LateComingCalculationOnPunchOut_Z2`](https://github.com/zinghrcore/z2-tna-db/blob/master/LateComingCalculationOnPunchOut_Z2.sql)
- **Step 7:** [Create SP `TNA.EarlyGoingCalculationOnPunchOut_Z2`](https://github.com/zinghrcore/z2-tna-db/blob/master/EarlyGoingCalculationOnPunchOut.sql)
- **Step 8:** [Create SP `PunchInOnLogin`](https://github.com/zinghrcore/z2-tna-db/blob/master/%5BTNA%5D.%5BPunchInOnLogin%5D.sql)
- **Step 9:** [Create SP `PunchInOnThroughBio_Z2`](https://github.com/zinghrcore/z2-tna-db/blob/master/PunchInOnThroughBio_z2.sql)

---

# 🕒 BackDated Attendance Process - TNA System

Process for executing **BackDated OT** attendance logic using SQL stored procedures.

### 📌 Job Name: `Attendance_job_for_cowayqa5`

### ✅ Steps:

- **Step 1:** [Generate FlatTable – `SetEmpShiftJSONData`](https://github.com/zinghrcore/z2-tna-db/blob/master/1.setempshiftjsondata.sql)
- **Step 2:** [Create FILO records – `FiloCreationWithJSON_Z2`](https://github.com/zinghrcore/z2-tna-db/blob/master/2.FiloCreationWithJSON_Z2.sql)
- **Step 3:** [Apply Working Hours Rule – `AttendanceRule_WorkingHrs`](https://github.com/zinghrcore/z2-tna-db/blob/master/3.AttendanceRule_WorkingHrs.sql)
- **Step 4:** [Apply Late Coming Rule – `ATTENDANCERULE_LATECOMING`](https://github.com/zinghrcore/z2-tna-db/blob/master/4.ATTENDANCERULE_LATECOMING.sql)
- **Step 5:** [Apply Early Going Rule – `ATTENDANCERULE_EARLYGOING`](https://github.com/zinghrcore/z2-tna-db/blob/master/5.ATTENDANCERULE_EARLYGOING.sql)
- **Step 6:** [Apply Flexitime Rule – `ATTENDANCERULE_FLEXITIME`](https://github.com/zinghrcore/z2-tna-db/blob/master/6.ATTENDANCERULE_FLEXITIME.sql)
- **Step 7:** [Process Extra Time – `GenExtraTimeZ2_AttProcess`](https://github.com/zinghrcore/z2-tna-db/blob/master/7.GenExtraTimeZ2_AttProcess.sql)
- **Step 8:** [Apply Compensatory Off Rule – `ATTENDANCERULE_COMPOFF`](https://github.com/zinghrcore/z2-tna-db/blob/master/8.ATTENDANCERULE_COMPOFF.sql)
- **Step 9:** [Handle Exceptions – `ATTENDANCERULE_EXCEPTIONS`](https://github.com/zinghrcore/z2-tna-db/blob/master/9.ATTENDANCERULE_EXCEPTIONS.sql)
- **Step 10:** [Display Attendance Results – `AttendanceRule_DisplayResult`](https://github.com/zinghrcore/z2-tna-db/blob/master/10.AttendanceRule_DisplayResult.sql)
- **Step 11:** [Transfer to Reporting – `DataTransferForReports`](https://github.com/zinghrcore/z2-tna-db/blob/master/11.DataTransferForReports.sql)

---

## 🌟 Contributors

<table width="100%">
  <tr>
    <td align="center">
      <a href="https://www.linkedin.com/in/prasad-rajappan-a002a73/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/C4E03AQEQl64iTddLkw/profile-displayphoto-shrink_400_400/0/1516298618284?e=1751500800&v=beta&t=QZ-WYMxK5vPV-_iFCikorpW6VSIWnhWAz7LlXiX5LXE" width="100px;" style="border-radius: 50%;" alt="Prasad"/><br />
        <sub><b>Prasad Rajappan</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://www.linkedin.com/in/nikhil004/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQGys4LpBZOvng/profile-displayphoto-shrink_200_200/0/1726168691780?e=2147483647&v=beta&t=7_LfxXThuPlIpSHmiPCQe1bwPCkJW52oAVhJOn5FL0E" width="100px;" style="border-radius: 50%;" alt="Nikhil"/><br />
        <sub><b>Nikhil Mishra</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://www.linkedin.com/in/hemant-meena-208b2556/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQE7YLjE5a77dg/profile-displayphoto-shrink_400_400/0/1743313384104?e=1751500800&v=beta&t=fMEISdFGYxEw5J4Wnki5WaBSIIsz9yD4aHsmx0F3Bq8" width="100px;" style="border-radius: 50%;" alt="Hemant"/><br />
        <sub><b>Hemant Meena</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://www.linkedin.com/in/mihir-mistry-93068b223/" target="_blank">
        <img src="https://media.licdn.com/dms/image/v2/D4D03AQEpLW8pg6DVgw/profile-displayphoto-shrink_200_200/0/1736967562482?e=2147483647&v=beta&t=HrPYZoofkqgqDIfavB3QjqSbbWQPP4aza3LomSTXoGk" width="100px;" style="border-radius: 50%;" alt="Mihir"/><br />
        <sub><b>Mihir Mistry</b></sub>
      </a>
    </td>
  </tr>
</table>

---

## 📁 Resources

- 📄 [Detailed Report (SharePoint)](https://zinghr365-my.sharepoint.com/:w:/g/personal/nikhil_mishra_zinghr_com/EQtXlIN-tVFKks0tMhePZmEBjwJWUVPBQbnlyqqT4rnOJQ?web=1)
- 📄 [Steps Report (Google Drive)](https://drive.google.com/file/d/1VrXBYQQknR33bqLG-Che7I3bnBFKTl6T/view?usp=drive_link)
- 📦 [All Tables and Stored Procedures](https://github.com/zinghrcore/z2-tna-db/blob/master/Final%20SP%20and%20tables.rar)

---

[🔝 Back to Top](#readme-top)

© 2025 [ZingHR](https://www.zinghr.com/)
