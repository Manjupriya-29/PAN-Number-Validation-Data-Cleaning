# PAN-Number-Validation-Data-Cleaning

**Objective**: To clean a dataset of 10,000 PAN numbers and validate them against official Indian government rules, categorizing each as Valid or Invalid, and generating a final summary report.

---

DATASET : [PAN NUMBER DATASET](Pan_Number_Validation_Dataset.csv)

---

My Final SQL Script is in [Project_script](project_scripts.sql)

---

**1. Project Overview & Rules**
**What is a PAN?**

- PAN stands for Permanent Account Number.

- It's a 10-digit unique alphanumeric identifier issued to Indian taxpayers.

- The project involves cleaning and validating a dataset of these numbers.

---

**Data Cleaning Rules:**

1.**Handle Missing Data**: Identify and remove entries where the PAN number is blank or null.

2.**Remove Duplicates**: Ensure each PAN number entry is unique.

3.**Trim Spaces**: Remove any leading or trailing spaces from the PAN number entries.

4.**Standardize Case**: Convert all PAN numbers to UPPERCASE.

---

**Validation Rules (The PAN Format):**
A valid PAN must adhere to the following structure: AAAAA1111A

- First 5 Characters: Must be uppercase letters (A-Z).

- Next 4 Characters: Must be digits (0-9).

- Last Character: Must be an uppercase letter (A-Z).

*Additional Validation Rules*:

For the first ***5 letters***:

- Rule 1: No two adjacent characters can be the same (e.g., AABCE is invalid, AXBCE is valid).

- Rule 2: All five characters cannot form a sequential pattern (e.g., ABCDE, BCDEF are invalid; ABCXE is valid).

For the next ***4 digits***:

- Rule 1: No two adjacent digits can be the same (e.g., 1123 is invalid, 1923 is valid).

- Rule 2: All four digits cannot form a sequential pattern (e.g., 1234, 2345 are invalid; 1239 is valid).

---

**Final Deliverables**:

1.Detailed Report: A list of all PAN numbers with a new column indicating their status as Valid or Invalid.

2.Summary Report: A high-level summary containing:

- Total records processed

- Total valid PANs

- Total invalid PANs

- Total missing/incomplete PANs

***Tools Used***: PostgreSQL

---

**2. Step-by-Step Implementation**

**1. Create a Staging Table**: Create a simple table with one column to hold the raw dat.
   
```

CREATE TABLE stg_pan_numbers_dataset (
    pan_number TEXT
);

```
**2. Data Cleaning**
The goal is to create a cleaned dataset by applying the four data cleaning rules. This is done in a single query using a Common Table Expression (CTE).

**Key SQL Functions Used**:

TRIM(): Removes leading and trailing spaces.

UPPER(): Converts text to uppercase.

DISTINCT: Removes duplicate records.

WHERE ... IS NOT NULL: Filters out null values.

***Cleaning Query***:

```
WITH cte_cleaned_pan AS (
    SELECT DISTINCT
        UPPER(TRIM(pan_number)) AS pan_number -- Applies rules 2, 3, and 4
    FROM stg_pan_number_dataset
    WHERE pan_number IS NOT NULL -- Handles missing data (Rule 1)
    AND TRIM(pan_number) <> '' -- Removes entries that are just empty strings
)
SELECT * FROM cte_cleaned_pan;

```

***Result***: This query returns 9,025 cleaned, unique PAN numbers ready for validation.

**3. Data Validation**
Validating the complex rules requires creating custom User-Defined Functions (UDFs).

*A) Create Function*: Check for Adjacent Characters
This function checks if any two adjacent characters in a string are identical.

```

CREATE OR REPLACE FUNCTION fn_check_adjacent_chars(p_str TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    FOR i IN 1..LENGTH(p_str) - 1 LOOP
        IF SUBSTRING(p_str, i, 1) = SUBSTRING(p_str, i+1, 1) THEN
            RETURN TRUE; -- Found adjacent duplicates
        END IF;
    END LOOP;
    RETURN FALSE; -- No adjacent duplicates found
END;
$$ LANGUAGE plpgsql;

```
**Usage**: SELECT fn_check_adjacent_chars('AABCE'); returns TRUE.
SELECT fn_check_adjacent_chars('AXBCE'); returns FALSE.

*B) Create Function*: Check for Sequential Characters
This function checks if all characters in a string are in sequential order (e.g., ABCDE) by comparing their ASCII values.

```

CREATE OR REPLACE FUNCTION fn_check_sequential_chars(p_str TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    FOR i IN 1..LENGTH(p_str) - 1 LOOP
        IF ASCII(SUBSTRING(p_str, i+1, 1)) - ASCII(SUBSTRING(p_str, i, 1)) != 1 THEN
            RETURN FALSE; -- Sequence is broken, not sequential
        END IF;
    END LOOP;
    RETURN TRUE; -- All consecutive chars are sequential
END;
$$ LANGUAGE plpgsql;

```

**Usage**: SELECT fn_check_sequential_chars('ABCDE'); returns TRUE.
SELECT fn_check_sequential_chars('ABCXE'); returns FALSE.

*C) Validate Format with Regular Expression*
Use a regex pattern to check the basic structure: 5 letters + 4 digits + 1 letter.

- ^[A-Z]{5}: Starts with exactly 5 uppercase letters.

- [0-9]{4}: Followed by exactly 4 digits.

- [A-Z]{1}$: Ends with exactly one uppercase letter.

**Pattern**: '^[A-Z]{5}[0-9]{4}[A-Z]$'

**4. Final Query for Valid/Invalid Categorization**

This query brings everything together: it uses the cleaned data, the custom functions, and the regex pattern to label each PAN as Valid or Invalid.

```

WITH cte_cleaned_pan AS (
    -- Cleaning query from Step 2 goes here
),
cte_valid_pan AS (
    SELECT pan_number
    FROM cte_cleaned_pan
    WHERE
        -- Check basic structure
        pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
        -- Check first 5 letters: no adjacent duplicates
        AND NOT fn_check_adjacent_chars(SUBSTRING(pan_number, 1, 5))
        -- Check first 5 letters: not a sequence
        AND NOT fn_check_sequential_chars(SUBSTRING(pan_number, 1, 5))
        -- Check next 4 digits: no adjacent duplicates
        AND NOT fn_check_adjacent_chars(SUBSTRING(pan_number, 6, 4))
        -- Check next 4 digits: not a sequence
        AND NOT fn_check_sequential_chars(SUBSTRING(pan_number, 6, 4))
)
SELECT
    cln.pan_number,
    CASE
        WHEN vld.pan_number IS NOT NULL THEN 'Valid PAN'
        ELSE 'Invalid PAN'
    END AS status
FROM cte_cleaned_pan cln
LEFT JOIN cte_valid_pan vld ON cln.pan_number = vld.pan_number;

```

**Result**: This query lists all 9,025 cleaned PANs with their validation status. The tutorial found 3,186 Valid and 5,839 Invalid PANs.

 **5. Create the Summary Report**
This query calculates the totals for the final report. It uses the FILTER clause for clean aggregation.

```

-- First, create a view for the detailed report for easier reuse
CREATE OR REPLACE VIEW view_valid_invalid_pans AS
-- (The entire final categorization query from Step 4 goes here)
;

-- Summary Report Query
WITH cte_totals AS (
    SELECT
        (SELECT COUNT(*) FROM stg_pan_numbers_dataset) AS total_processed_records,
        COUNT(*) FILTER (WHERE status = 'Valid PAN') AS total_valid_pans,
        COUNT(*) FILTER (WHERE status = 'Invalid PAN') AS total_invalid_pans
    FROM view_valid_invalid_pans
)
SELECT
    total_processed_records,
    total_valid_pans,
    total_invalid_pans,
    (total_processed_records - (total_valid_pans + total_invalid_pans)) AS total_missing_incomplete_pans
FROM cte_totals;

```
**Result**:

Total Processed Records: 10,000

Total Valid PANs: 3,186

Total Invalid PANs: 5,839

Total Missing/Incomplete PANs: 975 (10,000 - (3,186 + 5,839))

