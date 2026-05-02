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

-- THIS IS THE MAIN TABLE. Use this for most queries.
-- loan_amount_000s = the loan/mortgage value in thousands
-- applicant_income_000s = the applicant's income in thousands
-- To compare loan value vs income: WHERE loan_amount_000s > applicant_income_000s
-- There is NO table called "Applicant" — use "Application" instead.
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
