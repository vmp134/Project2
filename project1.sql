-- Timeout for slow joins on ilab
SET statement_timeout = '300000'; -- 5 minutes

-- Drop tables if they exist already -> Rebuild tables from scratch
DROP TABLE IF EXISTS Co_Applicant_Race CASCADE;
DROP TABLE IF EXISTS Applicant_Race CASCADE;
DROP TABLE IF EXISTS Denial CASCADE;
DROP TABLE IF EXISTS Application CASCADE;
DROP TABLE IF EXISTS Respondent CASCADE;
DROP TABLE IF EXISTS Applicant CASCADE;
DROP TABLE IF EXISTS Co_Applicant CASCADE;
DROP TABLE IF EXISTS Location CASCADE;
DROP TABLE IF EXISTS Edit_Status CASCADE;
DROP TABLE IF EXISTS Lien_Status CASCADE;
DROP TABLE IF EXISTS Hoepa_Status CASCADE;
DROP TABLE IF EXISTS Purchaser_Type CASCADE;
DROP TABLE IF EXISTS Denial_Reason CASCADE;
DROP TABLE IF EXISTS Race CASCADE;
DROP TABLE IF EXISTS Co_Applicant_Sex CASCADE;
DROP TABLE IF EXISTS Applicant_Sex CASCADE;
DROP TABLE IF EXISTS Co_Applicant_Ethnicity CASCADE;
DROP TABLE IF EXISTS Applicant_Ethnicity CASCADE;
DROP TABLE IF EXISTS County CASCADE;
DROP TABLE IF EXISTS State CASCADE;
DROP TABLE IF EXISTS Msamd CASCADE;
DROP TABLE IF EXISTS Action_Taken CASCADE;
DROP TABLE IF EXISTS Preapproval CASCADE;
DROP TABLE IF EXISTS Owner_Occupancy CASCADE;
DROP TABLE IF EXISTS Loan_Purpose CASCADE;
DROP TABLE IF EXISTS Property_Type CASCADE;
DROP TABLE IF EXISTS Loan_Type CASCADE;
DROP TABLE IF EXISTS Agency CASCADE;

CREATE TABLE Agency (
    agency_code INT PRIMARY KEY,
    agency_abbr TEXT NOT NULL,
    agency_name TEXT NOT NULL
);

CREATE TABLE Loan_Type (
    loan_type INT PRIMARY KEY,
    loan_type_name TEXT NOT NULL
);

CREATE TABLE Property_Type (
    property_type INT PRIMARY KEY,
    property_type_name TEXT NOT NULL
);

CREATE TABLE Loan_Purpose (
    loan_purpose INT PRIMARY KEY,
    loan_purpose_name TEXT NOT NULL
);

CREATE TABLE Owner_Occupancy (
    owner_occupancy INT PRIMARY KEY,
    owner_occupancy_name TEXT NOT NULL
);

CREATE TABLE Preapproval (
    preapproval INT PRIMARY KEY,
    preapproval_name TEXT NOT NULL
);

CREATE TABLE Action_Taken (
    action_taken INT PRIMARY KEY,
    action_taken_name TEXT NOT NULL
);

CREATE TABLE Msamd (
    msamd INT PRIMARY KEY,
    msamd_name TEXT
);

CREATE TABLE State (
    state_code INT PRIMARY KEY,
    state_name TEXT NOT NULL,
    state_abbr TEXT NOT NULL
);

CREATE TABLE County (
    county_code INT PRIMARY KEY,
    county_name TEXT NOT NULL
);

CREATE TABLE Applicant_Ethnicity (
    applicant_ethnicity INT PRIMARY KEY,
    applicant_ethnicity_name TEXT NOT NULL
);

CREATE TABLE Co_Applicant_Ethnicity (
    co_applicant_ethnicity INT PRIMARY KEY,
    co_applicant_ethnicity_name TEXT NOT NULL
);

CREATE TABLE Applicant_Sex (
    applicant_sex INT PRIMARY KEY,
    applicant_sex_name TEXT NOT NULL
);

CREATE TABLE Co_Applicant_Sex (
    co_applicant_sex INT PRIMARY KEY,
    co_applicant_sex_name TEXT NOT NULL
);

CREATE TABLE Purchaser_Type (
    purchaser_type INT PRIMARY KEY,
    purchaser_type_name TEXT NOT NULL
);

CREATE TABLE Hoepa_Status (
    hoepa_status INT PRIMARY KEY,
    hoepa_status_name TEXT NOT NULL
);

CREATE TABLE Lien_Status (
    lien_status INT PRIMARY KEY,
    lien_status_name TEXT NOT NULL
);

CREATE TABLE Edit_Status (
    edit_status INT PRIMARY KEY,
    edit_status_name TEXT NOT NULL
);

CREATE TABLE Denial_Reason (
    denial_reason INT PRIMARY KEY,
    denial_reason_name TEXT NOT NULL
);

CREATE TABLE Race (
    race_code INT PRIMARY KEY,
    race_name TEXT NOT NULL
);


CREATE TABLE Respondent (
    respondent_id TEXT PRIMARY KEY,
    agency_code INT REFERENCES Agency(agency_code)
);

CREATE TABLE Location (
    LocationID SERIAL PRIMARY KEY,
    county_code INT REFERENCES County(county_code),
    msamd INT REFERENCES Msamd(msamd),
    state_code INT REFERENCES State(state_code),
    census_tract_number DECIMAL(6,2),
    population INT,
    minority_population DECIMAL(20,13),
    hud_median_family_income INT,
    tract_to_msamd_income DECIMAL(20,13),
    number_of_owner_occupied_units INT,
    number_of_1_to_4_family_units INT
);


CREATE TABLE Application (
    ApplicationID SERIAL PRIMARY KEY,
    prelim_id INT,
    as_of_year INT,
    respondent_id TEXT REFERENCES Respondent(respondent_id),
    loan_type INT REFERENCES Loan_Type(loan_type),
    property_type INT REFERENCES Property_Type(property_type),
    loan_purpose INT REFERENCES Loan_Purpose(loan_purpose),
    owner_occupancy INT REFERENCES Owner_Occupancy(owner_occupancy),
    loan_amount_000s INT,
    preapproval INT REFERENCES Preapproval(preapproval),
    action_taken INT REFERENCES Action_Taken(action_taken),
    applicant_ethnicity INT REFERENCES Applicant_Ethnicity(applicant_ethnicity),
    co_applicant_ethnicity INT REFERENCES Co_Applicant_Ethnicity(co_applicant_ethnicity),
    applicant_sex INT REFERENCES Applicant_Sex(applicant_sex),
    co_applicant_sex INT REFERENCES Co_Applicant_Sex(co_applicant_sex),
    applicant_income_000s INT,
    purchaser_type INT REFERENCES Purchaser_Type(purchaser_type),
    rate_spread DECIMAL(5,2),
    hoepa_status INT REFERENCES Hoepa_Status(hoepa_status),
    lien_status INT REFERENCES Lien_Status(lien_status),
    edit_status INT REFERENCES Edit_Status(edit_status),
    sequence_number INT,
    application_date_indicator INT,
    LocationID INT REFERENCES Location(LocationID)
);

CREATE TABLE Denial (
    ApplicationID INT REFERENCES Application(ApplicationID),
    denial_reason INT REFERENCES Denial_Reason(denial_reason),
    denial_reason_number INT
);

CREATE TABLE Applicant_Race (
    ApplicationID INT REFERENCES Application(ApplicationID),
    applicant_race_code INT REFERENCES Race(race_code),
    applicant_race_number INT
);

CREATE TABLE Co_Applicant_Race (
    ApplicationID INT REFERENCES Application(ApplicationID),
    co_applicant_race_code INT REFERENCES Race(race_code),
    co_applicant_race_number INT
);




INSERT INTO Agency (agency_code, agency_abbr, agency_name)
SELECT DISTINCT CAST(NULLIF(agency_code,'') AS INT), NULLIF(agency_abbr,''), NULLIF(agency_name,'')
FROM Preliminary
WHERE NULLIF(agency_code,'') IS NOT NULL AND NULLIF(agency_abbr,'') IS NOT NULL AND NULLIF(agency_name,'') IS NOT NULL;

INSERT INTO Loan_Type (loan_type, loan_type_name)
SELECT DISTINCT CAST(NULLIF(loan_type,'') AS INT), NULLIF(loan_type_name,'')
FROM Preliminary WHERE NULLIF(loan_type,'') IS NOT NULL AND NULLIF(loan_type_name,'') IS NOT NULL;

INSERT INTO Property_Type (property_type, property_type_name)
SELECT DISTINCT CAST(NULLIF(property_type,'') AS INT), NULLIF(property_type_name,'')
FROM Preliminary WHERE NULLIF(property_type,'') IS NOT NULL AND NULLIF(property_type_name,'') IS NOT NULL;

INSERT INTO Loan_Purpose (loan_purpose, loan_purpose_name)
SELECT DISTINCT CAST(NULLIF(loan_purpose,'') AS INT), NULLIF(loan_purpose_name,'')
FROM Preliminary WHERE NULLIF(loan_purpose,'') IS NOT NULL AND NULLIF(loan_purpose_name,'') IS NOT NULL;

INSERT INTO Owner_Occupancy (owner_occupancy, owner_occupancy_name)
SELECT DISTINCT CAST(NULLIF(owner_occupancy,'') AS INT), NULLIF(owner_occupancy_name,'')
FROM Preliminary WHERE NULLIF(owner_occupancy,'') IS NOT NULL AND NULLIF(owner_occupancy_name,'') IS NOT NULL;

INSERT INTO Preapproval (preapproval, preapproval_name)
SELECT DISTINCT CAST(NULLIF(preapproval,'') AS INT), NULLIF(preapproval_name,'')
FROM Preliminary WHERE NULLIF(preapproval,'') IS NOT NULL AND NULLIF(preapproval_name,'') IS NOT NULL;

INSERT INTO Action_Taken (action_taken, action_taken_name)
SELECT DISTINCT CAST(NULLIF(action_taken,'') AS INT), NULLIF(action_taken_name,'')
FROM Preliminary WHERE NULLIF(action_taken,'') IS NOT NULL AND NULLIF(action_taken_name,'') IS NOT NULL;

INSERT INTO Msamd (msamd, msamd_name)
SELECT DISTINCT CAST(NULLIF(msamd,'') AS INT), NULLIF(msamd_name,'')
FROM Preliminary WHERE NULLIF(msamd,'') IS NOT NULL;

INSERT INTO State (state_code, state_name, state_abbr)
SELECT DISTINCT CAST(NULLIF(state_code,'') AS INT), NULLIF(state_name,''), NULLIF(state_abbr,'')
FROM Preliminary WHERE NULLIF(state_code,'') IS NOT NULL AND NULLIF(state_name,'') IS NOT NULL AND NULLIF(state_abbr,'') IS NOT NULL;

INSERT INTO County (county_code, county_name)
SELECT DISTINCT CAST(NULLIF(county_code,'') AS INT), NULLIF(county_name,'')
FROM Preliminary WHERE NULLIF(county_code,'') IS NOT NULL AND NULLIF(county_name,'') IS NOT NULL;

INSERT INTO Applicant_Ethnicity (applicant_ethnicity, applicant_ethnicity_name)
SELECT DISTINCT CAST(NULLIF(applicant_ethnicity,'') AS INT), NULLIF(applicant_ethnicity_name,'')
FROM Preliminary WHERE NULLIF(applicant_ethnicity,'') IS NOT NULL AND NULLIF(applicant_ethnicity_name,'') IS NOT NULL;

INSERT INTO Co_Applicant_Ethnicity (co_applicant_ethnicity, co_applicant_ethnicity_name)
SELECT DISTINCT CAST(NULLIF(co_applicant_ethnicity,'') AS INT), NULLIF(co_applicant_ethnicity_name,'')
FROM Preliminary WHERE NULLIF(co_applicant_ethnicity,'') IS NOT NULL AND NULLIF(co_applicant_ethnicity_name,'') IS NOT NULL;

INSERT INTO Applicant_Sex (applicant_sex, applicant_sex_name)
SELECT DISTINCT CAST(NULLIF(applicant_sex,'') AS INT), NULLIF(applicant_sex_name,'')
FROM Preliminary WHERE NULLIF(applicant_sex,'') IS NOT NULL AND NULLIF(applicant_sex_name,'') IS NOT NULL;

INSERT INTO Co_Applicant_Sex (co_applicant_sex, co_applicant_sex_name)
SELECT DISTINCT CAST(NULLIF(co_applicant_sex,'') AS INT), NULLIF(co_applicant_sex_name,'')
FROM Preliminary WHERE NULLIF(co_applicant_sex,'') IS NOT NULL AND NULLIF(co_applicant_sex_name,'') IS NOT NULL;

INSERT INTO Purchaser_Type (purchaser_type, purchaser_type_name)
SELECT DISTINCT CAST(NULLIF(purchaser_type,'') AS INT), NULLIF(purchaser_type_name,'')
FROM Preliminary WHERE NULLIF(purchaser_type,'') IS NOT NULL AND NULLIF(purchaser_type_name,'') IS NOT NULL;

INSERT INTO Hoepa_Status (hoepa_status, hoepa_status_name)
SELECT DISTINCT CAST(NULLIF(hoepa_status,'') AS INT), NULLIF(hoepa_status_name,'')
FROM Preliminary WHERE NULLIF(hoepa_status,'') IS NOT NULL AND NULLIF(hoepa_status_name,'') IS NOT NULL;

INSERT INTO Lien_Status (lien_status, lien_status_name)
SELECT DISTINCT CAST(NULLIF(lien_status,'') AS INT), NULLIF(lien_status_name,'')
FROM Preliminary WHERE NULLIF(lien_status,'') IS NOT NULL AND NULLIF(lien_status_name,'') IS NOT NULL;

INSERT INTO Edit_Status (edit_status, edit_status_name)
SELECT DISTINCT CAST(NULLIF(edit_status,'') AS INT), NULLIF(edit_status_name,'')
FROM Preliminary WHERE NULLIF(edit_status,'') IS NOT NULL AND NULLIF(edit_status_name,'') IS NOT NULL;

INSERT INTO Denial_Reason (denial_reason, denial_reason_name)
SELECT DISTINCT CAST(NULLIF(denial_reason_1,'') AS INT), NULLIF(denial_reason_name_1,'')
FROM Preliminary WHERE NULLIF(denial_reason_1,'') IS NOT NULL AND NULLIF(denial_reason_name_1,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(denial_reason_2,'') AS INT), NULLIF(denial_reason_name_2,'')
FROM Preliminary WHERE NULLIF(denial_reason_2,'') IS NOT NULL AND NULLIF(denial_reason_name_2,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(denial_reason_3,'') AS INT), NULLIF(denial_reason_name_3,'')
FROM Preliminary WHERE NULLIF(denial_reason_3,'') IS NOT NULL AND NULLIF(denial_reason_name_3,'') IS NOT NULL;

INSERT INTO Race (race_code, race_name)
SELECT DISTINCT CAST(NULLIF(applicant_race_1,'') AS INT), NULLIF(applicant_race_name_1,'')
FROM Preliminary WHERE NULLIF(applicant_race_1,'') IS NOT NULL AND NULLIF(applicant_race_name_1,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(applicant_race_2,'') AS INT), NULLIF(applicant_race_name_2,'')
FROM Preliminary WHERE NULLIF(applicant_race_2,'') IS NOT NULL AND NULLIF(applicant_race_name_2,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(applicant_race_3,'') AS INT), NULLIF(applicant_race_name_3,'')
FROM Preliminary WHERE NULLIF(applicant_race_3,'') IS NOT NULL AND NULLIF(applicant_race_name_3,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(applicant_race_4,'') AS INT), NULLIF(applicant_race_name_4,'')
FROM Preliminary WHERE NULLIF(applicant_race_4,'') IS NOT NULL AND NULLIF(applicant_race_name_4,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(applicant_race_5,'') AS INT), NULLIF(applicant_race_name_5,'')
FROM Preliminary WHERE NULLIF(applicant_race_5,'') IS NOT NULL AND NULLIF(applicant_race_name_5,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(co_applicant_race_1,'') AS INT), NULLIF(co_applicant_race_name_1,'')
FROM Preliminary WHERE NULLIF(co_applicant_race_1,'') IS NOT NULL AND NULLIF(co_applicant_race_name_1,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(co_applicant_race_2,'') AS INT), NULLIF(co_applicant_race_name_2,'')
FROM Preliminary WHERE NULLIF(co_applicant_race_2,'') IS NOT NULL AND NULLIF(co_applicant_race_name_2,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(co_applicant_race_3,'') AS INT), NULLIF(co_applicant_race_name_3,'')
FROM Preliminary WHERE NULLIF(co_applicant_race_3,'') IS NOT NULL AND NULLIF(co_applicant_race_name_3,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(co_applicant_race_4,'') AS INT), NULLIF(co_applicant_race_name_4,'')
FROM Preliminary WHERE NULLIF(co_applicant_race_4,'') IS NOT NULL AND NULLIF(co_applicant_race_name_4,'') IS NOT NULL
UNION
SELECT DISTINCT CAST(NULLIF(co_applicant_race_5,'') AS INT), NULLIF(co_applicant_race_name_5,'')
FROM Preliminary WHERE NULLIF(co_applicant_race_5,'') IS NOT NULL AND NULLIF(co_applicant_race_name_5,'') IS NOT NULL;



INSERT INTO Respondent (respondent_id, agency_code)
SELECT NULLIF(respondent_id,''), MIN(CAST(NULLIF(agency_code,'') AS INT))
FROM Preliminary
WHERE NULLIF(respondent_id,'') IS NOT NULL
GROUP BY NULLIF(respondent_id,'');

INSERT INTO Respondent (respondent_id, agency_code)
SELECT NULLIF(respondent_id,''), NULL
FROM Preliminary
WHERE NULLIF(respondent_id,'') IS NOT NULL
  AND NULLIF(respondent_id,'') NOT IN (SELECT respondent_id FROM Respondent WHERE respondent_id IS NOT NULL)
GROUP BY NULLIF(respondent_id,'');

INSERT INTO Location (
    county_code, msamd, state_code, census_tract_number,
    population, minority_population, hud_median_family_income,
    tract_to_msamd_income, number_of_owner_occupied_units, number_of_1_to_4_family_units
)
SELECT DISTINCT
    CAST(NULLIF(county_code,'') AS INT),
    CAST(NULLIF(msamd,'') AS INT),
    CAST(NULLIF(state_code,'') AS INT),
    CAST(NULLIF(census_tract_number,'') AS DECIMAL(10,2)),
    CAST(NULLIF(population,'') AS INT),
    CAST(NULLIF(minority_population,'') AS DECIMAL(20,13)),
    CAST(NULLIF(hud_median_family_income,'') AS INT),
    CAST(NULLIF(tract_to_msamd_income,'') AS DECIMAL(20,13)),
    CAST(NULLIF(number_of_owner_occupied_units,'') AS INT),
    CAST(NULLIF(number_of_1_to_4_family_units,'') AS INT)
FROM Preliminary
WHERE NULLIF(state_code,'') IS NOT NULL AND NULLIF(county_code,'') IS NOT NULL;

CREATE INDEX idx_location_composite ON Location (
    county_code, msamd, state_code, census_tract_number,
    population, hud_median_family_income,
    number_of_owner_occupied_units, number_of_1_to_4_family_units
);

INSERT INTO Application (
    prelim_id, as_of_year, respondent_id,
    loan_type, property_type, loan_purpose, owner_occupancy,
    loan_amount_000s, preapproval, action_taken,
    applicant_ethnicity, co_applicant_ethnicity,
    applicant_sex, co_applicant_sex, applicant_income_000s,
    purchaser_type, rate_spread, hoepa_status, lien_status,
    edit_status, sequence_number, application_date_indicator, LocationID
)
SELECT
    p.id,
    CAST(NULLIF(p.as_of_year,'') AS INT),
    NULLIF(p.respondent_id,''),
    CAST(NULLIF(p.loan_type,'') AS INT),
    CAST(NULLIF(p.property_type,'') AS INT),
    CAST(NULLIF(p.loan_purpose,'') AS INT),
    CAST(NULLIF(p.owner_occupancy,'') AS INT),
    CAST(NULLIF(p.loan_amount_000s,'') AS INT),
    CAST(NULLIF(p.preapproval,'') AS INT),
    CAST(NULLIF(p.action_taken,'') AS INT),
    CAST(NULLIF(p.applicant_ethnicity,'') AS INT),
    CAST(NULLIF(p.co_applicant_ethnicity,'') AS INT),
    CAST(NULLIF(p.applicant_sex,'') AS INT),
    CAST(NULLIF(p.co_applicant_sex,'') AS INT),
    CAST(NULLIF(p.applicant_income_000s,'') AS INT),
    CAST(NULLIF(p.purchaser_type,'') AS INT),
    CASE WHEN NULLIF(p.rate_spread,'') IS NULL THEN NULL
         ELSE CAST(p.rate_spread AS DECIMAL(5,2)) END,
    CAST(NULLIF(p.hoepa_status,'') AS INT),
    CAST(NULLIF(p.lien_status,'') AS INT),
    CAST(NULLIF(p.edit_status,'') AS INT),
    CAST(NULLIF(p.sequence_number,'') AS INT),
    CAST(NULLIF(p.application_date_indicator,'') AS INT),
    l.LocationID
FROM Preliminary p
LEFT JOIN Location l
  ON COALESCE(CAST(NULLIF(p.county_code,'') AS INT),-1) = COALESCE(l.county_code,-1)
 AND COALESCE(CAST(NULLIF(p.msamd,'') AS INT),-1) = COALESCE(l.msamd,-1)
 AND COALESCE(CAST(NULLIF(p.state_code,'') AS INT),-1) = COALESCE(l.state_code,-1)
 AND COALESCE(CAST(NULLIF(p.census_tract_number,'') AS DECIMAL(10,2)),-1) = COALESCE(l.census_tract_number,-1)
 AND COALESCE(CAST(NULLIF(p.population,'') AS INT),-1) = COALESCE(l.population,-1)
 AND COALESCE(CAST(NULLIF(p.minority_population,'') AS DECIMAL(20,13)),-1) = COALESCE(l.minority_population,-1)
 AND COALESCE(CAST(NULLIF(p.hud_median_family_income,'') AS INT),-1) = COALESCE(l.hud_median_family_income,-1)
 AND COALESCE(CAST(NULLIF(p.tract_to_msamd_income,'') AS DECIMAL(20,13)),-1) = COALESCE(l.tract_to_msamd_income,-1)
 AND COALESCE(CAST(NULLIF(p.number_of_owner_occupied_units,'') AS INT),-1) = COALESCE(l.number_of_owner_occupied_units,-1)
 AND COALESCE(CAST(NULLIF(p.number_of_1_to_4_family_units,'') AS INT),-1) = COALESCE(l.number_of_1_to_4_family_units,-1);

CREATE INDEX idx_app_prelim_id ON Application (prelim_id);


INSERT INTO Denial (ApplicationID, denial_reason, denial_reason_number)
SELECT a.ApplicationID, CAST(NULLIF(p.denial_reason_1,'') AS INT), 1
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.denial_reason_1,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.denial_reason_2,'') AS INT), 2
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.denial_reason_2,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.denial_reason_3,'') AS INT), 3
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.denial_reason_3,'') IS NOT NULL;

INSERT INTO Applicant_Race (ApplicationID, applicant_race_code, applicant_race_number)
SELECT a.ApplicationID, CAST(NULLIF(p.applicant_race_1,'') AS INT), 1
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.applicant_race_1,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.applicant_race_2,'') AS INT), 2
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.applicant_race_2,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.applicant_race_3,'') AS INT), 3
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.applicant_race_3,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.applicant_race_4,'') AS INT), 4
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.applicant_race_4,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.applicant_race_5,'') AS INT), 5
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.applicant_race_5,'') IS NOT NULL;

INSERT INTO Co_Applicant_Race (ApplicationID, co_applicant_race_code, co_applicant_race_number)
SELECT a.ApplicationID, CAST(NULLIF(p.co_applicant_race_1,'') AS INT), 1
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.co_applicant_race_1,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.co_applicant_race_2,'') AS INT), 2
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.co_applicant_race_2,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.co_applicant_race_3,'') AS INT), 3
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.co_applicant_race_3,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.co_applicant_race_4,'') AS INT), 4
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.co_applicant_race_4,'') IS NOT NULL
UNION ALL
SELECT a.ApplicationID, CAST(NULLIF(p.co_applicant_race_5,'') AS INT), 5
FROM Preliminary p JOIN Application a ON p.id = a.prelim_id
WHERE NULLIF(p.co_applicant_race_5,'') IS NOT NULL;

ALTER TABLE Application DROP COLUMN prelim_id;
