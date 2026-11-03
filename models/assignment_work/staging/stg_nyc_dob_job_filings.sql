-- Clean and standardize DOB NOW job filing data
-- One row per job filing

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
   SELECT
       -- Keep all other columns as they are
       * EXCEPT (
           job_filing_number,
           borough,
           council_district,
           zip,
           filing_date,
           current_status_date,
           first_permit_date,
           approved_date,
           signoff_date
       ),

       -- Identifier
       CAST(job_filing_number AS STRING) AS job_filing_id,

       -- Dates: cast to TIMESTAMP to match the 311 date columns
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Borough: same logic as the 311 model so values match
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       -- Council district as text so it matches across both sources
       CAST(council_district AS STRING) AS council_district,

       -- Zip: keep valid 5-digit values only
       CASE
           WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 5
           THEN TRIM(CAST(zip AS STRING))
           ELSE NULL
       END AS zip,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
     AND filing_date IS NOT NULL
     AND borough IS NOT NULL

   -- Deduplicate: keep the latest status per filing
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY job_filing_number
       ORDER BY current_status_date DESC
   ) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_dob_job_filings