USE ROLE accountadmin;

USE WAREHOUSE incubyte_wh;

-- Storage integration to S3 (credential-less, IAM role based)

CREATE STORAGE INTEGRATION IF NOT EXISTS incubyte_s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/incubyte-snowflake-access-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://incubyte_raw/');


-- into the trust policy of the AWS IAM role above. use the aws user arn link and external id link
DESC INTEGRATION incubyte_s3_integration;

--  File formats
CREATE FILE FORMAT IF NOT EXISTS INCUBYTE_ASSESSMENT.BRONZE.CSV_STANDARD
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'N/A');

CREATE FILE FORMAT IF NOT EXISTS INCUBYTE_ASSESSMENT.BRONZE.JSON_STANDARD
  TYPE = 'JSON';

--  External stages

CREATE STAGE IF NOT EXISTS INCUBYTE_ASSESSMENT.BRONZE.S3_INCUBYTE_STAGE
  STORAGE_INTEGRATION = incubyte_s3_integration
  URL = 's3://incubyte_raw/'
  FILE_FORMAT = INCUBYTE_ASSESSMENT.BRONZE.CSV_STANDARD;

-- Quick smoke test: list files Snowflake can see in the bucket

LIST @INCUBYTE_ASSESSMENT.BRONZE.S3_INCUBYTE_STAGE;





