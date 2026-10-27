-- RAW_REDEMPTIONS (JSON) -> REDEMPTIONS_FLAT, then join to the members

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE incubyte_wh;

INSERT OVERWRITE INTO INCUBYTE_ASSESSMENT.SILVAR.REDEMPTIONS_FLAT
    (REDEMPTION_ID, LINE_NO, MEMBER_ID, REDEEMED_AT, CHANNEL, REWARD_CODE, POINTS, QUANTITY, SOURCE_FILE)
SELECT
    NULLIF(TRIM(r.PAYLOAD:redemption_id::VARCHAR), '')            AS REDEMPTION_ID,
    COALESCE(i.INDEX, 0) + 1                                      AS LINE_NO,
    UPPER(NULLIF(TRIM(r.PAYLOAD:member_id::VARCHAR), ''))         AS MEMBER_ID,
    COALESCE(
        TRY_TO_TIMESTAMP_NTZ(r.PAYLOAD:redeemed_at::VARCHAR),
        TRY_TO_TIMESTAMP_NTZ(r.PAYLOAD:redeemed_at::VARCHAR, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    )                                                             AS REDEEMED_AT,
    NULLIF(TRIM(r.PAYLOAD:channel::VARCHAR), '')                  AS CHANNEL,
    NULLIF(TRIM(i.VALUE:reward_code::VARCHAR), '')                AS REWARD_CODE,
    TRY_TO_NUMBER(i.VALUE:points::VARCHAR)                        AS POINTS,
    TRY_TO_NUMBER(i.VALUE:quantity::VARCHAR)                      AS QUANTITY,
    r.SOURCE_FILE
FROM INCUBYTE_ASSESSMENT.BRONZE.RAW_REDEMPTIONS r,
     LATERAL FLATTEN(input => r.PAYLOAD:items, OUTER => TRUE) i;


     