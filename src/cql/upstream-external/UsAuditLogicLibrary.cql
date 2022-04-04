/*  Library: Alcohol Screening and Brief Intervention (ASBI) Clinical Decision Support (CDS): 
USAUDIT Logic Library
    Author: CMS Alliance to Modernize Healthcare, operated by THE MITRE Corporation.

    (C) 2021 The MITRE Corporation. All Rights Reserved. Approved for Public Release: 20-0458. 
    Distribution Unlimited.

    Unless otherwise noted, this work is available under an Apache 2.0 license. 
    It was produced by the MITRE Corporation for the National Center on Birth Defects 
    and Developmental Disabilities, Centers for Disease Control and Prevention in 
    accordance with the Statement of Work, contract number 75FCMC18D0047, task order 
    number 75D30119F05691.

    References to and reproductions of the AUDIT alcohol screening instrument are made 
    by permission from the World Health Organization (WHO). The WHO does not endorse 
    this project, does not provide any warranty, and does not assume any liability 
    for its use. For further information, please see:

    Alcohol Use Disorders Identification Test - Guidelines for Use in Primary Care, 
    Second Edition. Geneva, World Health Organization, 2001.

    AUDIT (C) World Health Organization 2001

    https://www.who.int/substance_abuse/activities/sbi/en/
*/
library UsAuditLogicLibrary version '1.1.0'
/* Change Log
- Version 1.1.0: Moving from FHIR 4.0.0 to 4.0.1 and CQL 1.4 to 1.5.
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// CODESYSTEMS, VALUE SETS, CODES, AND CONCEPTS
// -----------------------------------------------------------------------------

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'
codesystem "FHIR Condition Clinical Status": 'http://terminology.hl7.org/CodeSystem/condition-clinical'
codesystem "FHIR Condition Verification Status": 'http://terminology.hl7.org/CodeSystem/condition-ver-status'
codesystem "ADMINISTRATIVE GENDER": 'http://terminology.hl7.org/CodeSystem/v3-AdministrativeGender'
codesystem "NULL FLAVOR": 'http://terminology.hl7.org/CodeSystem/v3-NullFlavor'
codesystem "LOCAL": 'http://www.cdc.gov/ncbddd/fasd'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.526.3.378/expansion)
valueset "Pregnancy": '2.16.840.1.113883.3.526.3.378'
// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.80/expansion)
valueset "Pregnancy (New ICD10 codes published in 2018 and 2019)": '2.16.840.1.113762.1.4.1032.80'
// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.129/expansion)
valueset "AUD (i.e., Alcohol Use Disorder)": '2.16.840.1.113762.1.4.1032.129'
// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.148/expansion)
valueset "Hysterectomy": '2.16.840.1.113762.1.4.1032.148'

// Standard codes
code "Pregnancy status code": '82810-3' from "LOINC" display 'Pregnancy status'
code "Pregnant code": '77386006' from "SNOMED-CT" display 'Patient currently pregnant (finding)'
code "Confirmed verification status code": 'confirmed' from "FHIR Condition Verification Status" display 'Confirmed'
code "Active clinical status code": 'active' from "FHIR Condition Clinical Status" display 'Active'
code "Recurrence clinical status code": 'recurrence' from "FHIR Condition Clinical Status" display 'Recurrence'
code "Relapse clinical status code": 'relapse' from "FHIR Condition Clinical Status" display 'Relapse'
code "Inactive clinical status code": 'inactive' from "FHIR Condition Clinical Status" display 'Inactive'
code "Remission clinical status code": 'remission' from "FHIR Condition Clinical Status" display 'Remission'
code "Resolved clinical status code": 'resolved' from "FHIR Condition Clinical Status" display 'Resolved'
code "Male administrative gender code": 'M' from "ADMINISTRATIVE GENDER" display 'Male'
code "Female administrative gender code": 'F' from "ADMINISTRATIVE GENDER" display 'Female'
code "Unknown value code": 'UNK' from "NULL FLAVOR" display 'Unknown'
code "WHO AUDIT-C Total Score code": '75626-2' from "LOINC" display 'WHO AUDIT-C Total Score'
code "WHO AUDIT Total Score code": '75624-7' from "LOINC" display 'WHO AUDIT Total Score'

// Local (non-standard) codes
code "USAUDIT-C Total Score code": 'UACS' from "LOCAL" display 'USAUDIT-C Total Score'
code "USAUDIT Total Score code": 'UAFS' from "LOCAL" display 'USAUDIT Total Score'
code "Yes": 'yes' from "LOCAL" display 'Yes'
code "No": 'no' from "LOCAL" display 'No'
code "Never": 'never' from "LOCAL" display 'Never'

concept "Pregnancy status": { "Pregnancy status code" } display 'Pregnancy status'
concept "Pregnant": { "Pregnant code" } display 'Patient currently pregnant (finding)'
concept "Condition Confirmed": { "Confirmed verification status code" } display 'Confirmed'
concept "Condition Active": { "Active clinical status code" } display 'Active'
concept "Condition Recurrence": { "Recurrence clinical status code" } display 'Recurrence'
concept "Condition Relapse": { "Relapse clinical status code" } display 'Relapse'
concept "Condition Inactive": { "Inactive clinical status code" } display 'Inactive'
concept "Condition Remission": { "Remission clinical status code" } display 'Remission'
concept "Condition Resolved": { "Resolved clinical status code" } display 'Resolved'
concept "Alcohol screening codes": { 
  "WHO AUDIT-C Total Score code", "WHO AUDIT Total Score code" ,
  "USAUDIT-C Total Score code", "USAUDIT Total Score code"
  } display 'Alcohol screening codes'

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/usaudit'

// -----------------------------------------------------------------------------
// PATIENT INFORMATION
// -----------------------------------------------------------------------------
context Patient

// We need to set the QuestionnaireURL parameter to an expression before we can use it
define CurrentQuestionnaireURL:
  QuestionnaireURL

// The patient's sex at birth is used in several parts of the logic.
// Sex at birth defined according to Office of the National Coordinator (ONC) Interoperability Standards Advisory (ISA):
// https://www.healthit.gov/isa/representing-patient-sex-birth 
define SexAtBirthExtension:
  singleton from (Patient.extension Ext
    where Ext.url = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex')
  
define SexAtBirth:
  if SexAtBirthExtension is not null then 
    SexAtBirthExtension.value.value
  else "Unknown value code".code

define MaleAtBirth:
  SexAtBirth = "Male administrative gender code".code

define FemaleAtBirth:
  SexAtBirth = "Female administrative gender code".code

define SexAtBirthUnknown:
  SexAtBirth = "Unknown value code".code

// -----------------------------------------------------------------------------
// FUNCTIONS
// -----------------------------------------------------------------------------

define function ToCode(coding FHIR.Coding):
  FHIRHelpers.ToCode(coding)

define function ToConcept(concept FHIR.CodeableConcept):
  FHIRHelpers.ToConcept(concept)

// From the CDS Connect Commons Library
// Available from the Agency for Healthcare Research and Quality (AHRQ) under an 
// Apache 2.0 license. See https://cds.ahrq.gov
define function PeriodToInterval(period FHIR.Period):
  if period is null then
    null
  else
    Interval[period."start".value, period."end".value]

// -----------------------------------------------------------------------------
// INCLUSIONS LOGIC
// -----------------------------------------------------------------------------

define IsIncluded:
  AgeInYears() >= 18

// -----------------------------------------------------------------------------
// EXCLUSION LOGIC
// -----------------------------------------------------------------------------

// Verified pregnancy Observations in the last 42 weeks:
// Defined as FHIR Observations with the "Pregnancy status" code, from any time in the last 42 weeks, 
// with a value indicating patient is pregnant, and with a status indicating the Observation has been 
// verified.
define PregnancyObservations:
  [Observation: "Pregnancy status"] P
    let lookback: Interval[Now() - 42 weeks, Now()]
    where 
      ((P.effective as FHIR.dateTime).value in lookback
        or P.issued.value in lookback)
      and ToConcept(P.value as FHIR.CodeableConcept) ~ "Pregnant"
      and P.status.value in {'final', 'corrected', 'amended'}

define PregnancyConditions:
  ([Condition: "Pregnancy"] union [Condition: "Pregnancy (New ICD10 codes published in 2018 and 2019)"]) C
    let lookback: Interval[Now() - 42 weeks, Now()]
    where 
      ((C.onset as FHIR.dateTime).value in lookback
        or PeriodToInterval(C.onset as FHIR.Period) overlaps lookback
        or C.recordedDate.value in lookback)
      and (C.clinicalStatus ~ "Condition Active"
        or C.clinicalStatus ~ "Condition Recurrence")
      and C.verificationStatus ~ "Condition Confirmed"

// Is the current patient pregnant?
define IsPregnant:
  Exists(PregnancyObservations) or Exists(PregnancyConditions)

define SortedPregnancyObservationDates:
  (PregnancyObservations) P
  return Tuple {date: Coalesce(
    (P.effective as FHIR.dateTime).value,
    (P.effective as FHIR.instant).value,
    (P.effective as FHIR.Period)."end".value,
    (P.effective as FHIR.Period)."start".value,
    P.issued.value)}
  sort by date desc

define SortedPregnancyConditionDates:
  (PregnancyConditions) C
  return Tuple {date: Coalesce(
    (C.onset as FHIR.dateTime).value,
    (C.onset as FHIR.Period)."end".value,
    (C.onset as FHIR.Period)."start".value,
    C.recordedDate.value)}
  sort by date desc

define SortedPregnacyDates:
  (SortedPregnancyObservationDates union SortedPregnancyConditionDates) D
  sort by date desc

define MostRecentPregnancyDate:
  First(SortedPregnacyDates).date

// The lookback for previous alcohol screening results depends upon whether the patient is pregnant or not.
define RecentAlcoholScreeningLookbackStart:
  if not IsPregnant then
    Today() - 1 year
  else if MostRecentPregnancyDate > (Today() - 3 months) then
    MostRecentPregnancyDate
  else
    Today() - 3 months

// Load any previously completed QuestionnaireReponses from alcohol screening
define PreviouslyCompletedQuestionnaireResponses:
  [QuestionnaireResponse] QR
    where (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/usaudit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')
    or (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/audit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')
    or (QR.questionnaire.value = 'http://www.cdc.gov/ncbddd/fasd/nidaqs2usaudit'
      and date from QR.authored.value between RecentAlcoholScreeningLookbackStart and Today()
      and QR.status.value = 'completed')

// Get the response items from these previously completed QuestionnaireResponses
define PreviouslyCompletedResponseItems:
  PreviouslyCompletedQuestionnaireResponses QR
  return all QR.item

// Reshape the response items to make them easier to process
define PreviouslyCompletedResponseValues:
  (flatten PreviouslyCompletedResponseItems) T return all Tuple {
    id: T.linkId.value,
    answer: T.answer.value[0]
  }

// Find any previous USAUDIT-C scores
define RecentScoreUsAuditC:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'usauditc-score'
  return RV.answer.value

// Have they received a USAUDIT-C score before?
define HasRecentScoreUsAuditC:
  Exists(RecentScoreUsAuditC)

// Find any previous full USAUDIT scores
define RecentScoreFullUsAudit:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'usaudit-score'
  return RV.answer.value

// Have they received a full USAUDIT score before?
define HasRecentScoreFullUsAudit:
  Exists(RecentScoreFullUsAudit)

// Find any previous AUDIT-C scores
define RecentScoreAuditC:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'auditc-score'
  return RV.answer.value

// Have they received an AUDIT-C score before?
define HasRecentScoreAuditC:
  Exists(RecentScoreAuditC)
  
// Find any previous full AUDIT scores
define RecentScoreFullAudit:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'audit-score'
  return RV.answer.value

// Have they received a full AUDIT score before?
define HasRecentScoreFullAudit:
  Exists(RecentScoreFullAudit)

// Recent responses to the alcohol pre-screen (APS) question
define RecentApsResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'prescreen-question'
  return RV.answer

// Recent APS "Yes" responses
define RecentApsYesResponses:
  (RecentApsResponses) R
  where R ~ "Yes"

// Recent APS "No" responses
define RecentApsNoResponses:
  (RecentApsResponses) R
  where R ~ "No"

// Have they recently answered "Yes" to the APS question?
define HasRecentYesApsResponse:
  Exists(RecentApsYesResponses)

// Have they recently answered "No" to the APS question?
define HasRecentNoApsResponse:
  Exists(RecentApsNoResponses)

// Recent responses to the USAUDIT Question 1
define RecentUsauditQuestionOneResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'usaudit-question-one'
  return RV.answer

// Recent responses to the AUDIT Question 1
define RecentAuditQuestionOneResponses:
  (PreviouslyCompletedResponseValues) RV
  where RV.id = 'audit-question-one'
  return RV.answer

// Have they recently answered "Never" to Question One of the USAUDIT?
define HasRecentNeverResponseUsauditQuestionOne:
  "Never" in RecentUsauditQuestionOneResponses

// Have they recently answered "Never" to Question One of the AUDIT?
define HasRecentNeverResponseAuditQuestionOne:
  "Never" in RecentAuditQuestionOneResponses

define RecentAlcoholScreeningObservations:
  [Observation: "Alcohol screening codes"] O
    where 
      (date from O.effective.value between RecentAlcoholScreeningLookbackStart and Today()
        or date from O.issued.value between RecentAlcoholScreeningLookbackStart and Today())
      and O.status.value in {'final', 'corrected', 'amended'}

define HasRecentAlcoholScreeningObservations:
  Exists(RecentAlcoholScreeningObservations)

// Is there any evidence of a recent alcohol screening?
define HasEvidenceOfRecentAlcoholScreening:
  HasRecentScoreUsAuditC
  or HasRecentScoreFullUsAudit
  or HasRecentScoreAuditC
  or HasRecentScoreFullAudit
  or HasRecentNoApsResponse
  or (HasRecentYesApsResponse
    and (
      HasRecentNeverResponseUsauditQuestionOne
      or HasRecentNeverResponseAuditQuestionOne
    ))
  or HasRecentAlcoholScreeningObservations

define AlcoholUseDisorders:
  [Condition: "AUD (i.e., Alcohol Use Disorder)"]

define InactiveAlcoholUseDisorders:
  (AlcoholUseDisorders) A
    where (A.clinicalStatus ~ "Condition Inactive"
      or A.clinicalStatus ~ "Condition Remission"
      or A.clinicalStatus ~ "Condition Resolved")
    and A.verificationStatus ~ "Condition Confirmed"

define HadButDoesNotCurrentlyHaveAlcoholUseDisorder:
  Exists(InactiveAlcoholUseDisorders)

define ActiveAlcoholUseDisorders:
  (AlcoholUseDisorders) A
    where (A.clinicalStatus ~ "Condition Active"
      or A.clinicalStatus ~ "Condition Recurrence"
      or A.clinicalStatus ~ "Condition Relapse")
    and A.verificationStatus ~ "Condition Confirmed"

define HasAlcoholUseDisorder:
  Exists(ActiveAlcoholUseDisorders)

define Excluded:
  HasEvidenceOfRecentAlcoholScreening
  or HasAlcoholUseDisorder

define ApplyScreeningInstrument:
  IsIncluded and not Excluded

// Is used as part of the exclusion for the pregnancy question
define HasHadHysterectomy:
  Exists([Procedure: "Hysterectomy"] P
    where P.status.value = 'completed')

//------------------------------------------------------------------------------
// QUESTIONNAIRE AND QUESTIONNAIRERESPONSE LOGIC
//------------------------------------------------------------------------------

// Question #3 Text:
// "How often do you have X (5 for men; 4 for women and men over 65) or
// more drinks on one occasion?"
define UsAuditQuestion3Text:
  if (AgeInYears() <= 65 and MaleAtBirth) then
    'How often do you have 5 or more drinks on one occasion?'
  else
    'How often do you have 4 or more drinks on one occasion?'

// NIDA Quick Screen (QS) Alcohol Question Text
// "In the past year, how often have you had X (5 for men; 4 for women and 
// men over 65) or more drinks a day?"
define NidaQsAlcoholQuestionText:
  if (AgeInYears() <= 65 and MaleAtBirth) then
    'In the past year, how often have you had five or more drinks a day?'
  else
    'In the past year, how often have you had four or more drinks a day?'

// Load Questionnaire
define UsAuditQuestionnaire:
  singleton from ([Questionnaire] Q
    where Q.url.value = CurrentQuestionnaireURL)

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  UsAuditQuestionnaire Q
  let item: Q.item
  return item.linkId.value

// Determine the index of each question based upon the extracted link ID
define IndexOfQuestion:
  {
    prescreen: IndexOf(ItemLinkIds, 'prescreen-question'),
    one: IndexOf(ItemLinkIds, 'usaudit-question-one'),
    two: IndexOf(ItemLinkIds, 'usaudit-question-two'),
    three: IndexOf(ItemLinkIds, 'usaudit-question-three'),
    auditcscore: IndexOf(ItemLinkIds, 'usauditc-score'),
    four: IndexOf(ItemLinkIds, 'usaudit-question-four'),
    five: IndexOf(ItemLinkIds, 'usaudit-question-five'),
    six: IndexOf(ItemLinkIds, 'usaudit-question-six'),
    seven: IndexOf(ItemLinkIds, 'usaudit-question-seven'),
    eight: IndexOf(ItemLinkIds, 'usaudit-question-eight'),
    nine: IndexOf(ItemLinkIds, 'usaudit-question-nine'),
    ten: IndexOf(ItemLinkIds, 'usaudit-question-ten')
  }

// Load the QuestionnaireResponse currently being filled out
define CurrentQuestionnaireResponse:
  singleton from ([QuestionnaireResponse] QR
    where QR.questionnaire.value = CurrentQuestionnaireURL
      and date from QR.authored.value same as Today()
      and QR.status.value = 'in-progress')

// Extract the items from the QuestionnaireResponse
define CurrentResponseItems:
  CurrentQuestionnaireResponse QR
  return QR.item

// Extract the answers from each item in the QuestionnaireResponse
define CurrentResponses:
  (CurrentResponseItems) I
  return Tuple {
    id: I.linkId.value,
    answer: I.answer.value[0] // Assuming only one answer per question
  }

// Pre-screen
define CurrentResponsePrescreen:
  CurrentResponses R
  where R.id = 'prescreen-question'
  return R.answer

// Question 1
define UsAuditAnswerOptionsQuestion1:
  UsAuditQuestionnaire.item[IndexOfQuestion.one].answerOption.value.code.value

define CurrentResponse1:
  CurrentResponses R
  where R.id = 'usaudit-question-one'
  return R.answer

define UsAuditResponseIndex1:
  if Exists(CurrentResponse1) then
    IndexOf(UsAuditAnswerOptionsQuestion1, singleton from CurrentResponse1.code.value as String)
  else
    -1

define UsAuditScoreQuestion1:
  if UsAuditResponseIndex1 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.one].answerOption[UsAuditResponseIndex1].extension[0].value.value as Integer
  else
    0

// Question 2
define UsAuditAnswerOptionsQuestion2:
  UsAuditQuestionnaire.item[IndexOfQuestion.two].answerOption.value.code.value

define CurrentResponse2:
  CurrentResponses R
  where R.id = 'usaudit-question-two'
  return R.answer

define UsAuditResponseIndex2:
  if Exists(CurrentResponse2) then
    IndexOf(UsAuditAnswerOptionsQuestion2, singleton from CurrentResponse2.code.value as String)
  else
    -1

define UsAuditScoreQuestion2:
  if UsAuditResponseIndex2 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.two].answerOption[UsAuditResponseIndex2].extension[0].value.value as Integer
  else
    0

// Question 3
define UsAuditAnswerOptionsQuestion3:
  UsAuditQuestionnaire.item[IndexOfQuestion.three].answerOption.value.code.value

define CurrentResponse3:
  CurrentResponses R
  where R.id = 'usaudit-question-three'
  return R.answer

define UsAuditResponseIndex3:
  if Exists(CurrentResponse3) then
    IndexOf(UsAuditAnswerOptionsQuestion3, singleton from CurrentResponse3.code.value as String)
  else
    -1

define UsAuditScoreQuestion3:
  if UsAuditResponseIndex3 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.three].answerOption[UsAuditResponseIndex3].extension[0].value.value as Integer
  else
    0

// Calculate the score for the USAUDIT-C
define ScoreUsAuditC:
  UsAuditScoreQuestion1 + UsAuditScoreQuestion2 + UsAuditScoreQuestion3

define AnsweredQuestionsOneThroughThree:
  Exists(CurrentResponse1)
    and Exists(CurrentResponse2)
    and Exists(CurrentResponse3)

// Should the score for the USAUDIT-C be displayed?
define DisplayScoreUsAuditC:
  AnsweredQuestionsOneThroughThree
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Determine AUDIT-C threshold for determining whether to progress to full AUDIT
define ThresholdUsAuditC:
  if FemaleAtBirth
    or SexAtBirthUnknown
    or (MaleAtBirth and AgeInYears() > 65)
  then 7
  else 8 // (SexAtBirth = 'Male' and AgeInYears <= 65)

// Should Questions #4 - #8 be displayed?
define DisplayUsAuditQuestions4to8:
  ScoreUsAuditC >= ThresholdUsAuditC
    and singleton from CurrentResponse1 !~ "Never"
    and singleton from CurrentResponsePrescreen ~ "Yes"

// Question 4
define UsAuditAnswerOptionsQuestion4:
  UsAuditQuestionnaire.item[IndexOfQuestion.four].answerOption.value.code.value

define CurrentResponse4:
  CurrentResponses R
  where R.id = 'usaudit-question-four'
  return R.answer

define UsAuditResponseIndex4:
  if Exists(CurrentResponse4) then
    IndexOf(UsAuditAnswerOptionsQuestion4, singleton from CurrentResponse4.code.value as String)
  else
    -1

define UsAuditScoreQuestion4:
  if UsAuditResponseIndex4 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.four].answerOption[UsAuditResponseIndex4].extension[0].value.value as Integer
  else
    0

// Question 5
define UsAuditAnswerOptionsQuestion5:
  UsAuditQuestionnaire.item[IndexOfQuestion.five].answerOption.value.code.value

define CurrentResponse5:
  CurrentResponses R
  where R.id = 'usaudit-question-five'
  return R.answer

define UsAuditResponseIndex5:
  if Exists(CurrentResponse5) then
    IndexOf(UsAuditAnswerOptionsQuestion5, singleton from CurrentResponse5.code.value as String)
  else
    -1

define UsAuditScoreQuestion5:
  if UsAuditResponseIndex5 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.five].answerOption[UsAuditResponseIndex5].extension[0].value.value as Integer
  else
    0

// Question 6
define UsAuditAnswerOptionsQuestion6:
  UsAuditQuestionnaire.item[IndexOfQuestion.six].answerOption.value.code.value

define CurrentResponse6:
  CurrentResponses R
  where R.id = 'usaudit-question-six'
  return R.answer

define UsAuditResponseIndex6:
  if Exists(CurrentResponse6) then
    IndexOf(UsAuditAnswerOptionsQuestion6, singleton from CurrentResponse6.code.value as String)
  else
    -1

define UsAuditScoreQuestion6:
  if UsAuditResponseIndex6 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.six].answerOption[UsAuditResponseIndex6].extension[0].value.value as Integer
  else
    0

// Question 7
define UsAuditAnswerOptionsQuestion7:
  UsAuditQuestionnaire.item[IndexOfQuestion.seven].answerOption.value.code.value

define CurrentResponse7:
  CurrentResponses R
  where R.id = 'usaudit-question-seven'
  return R.answer

define UsAuditResponseIndex7:
  if Exists(CurrentResponse7) then
    IndexOf(UsAuditAnswerOptionsQuestion7, singleton from CurrentResponse7.code.value as String)
  else
    -1

define UsAuditScoreQuestion7:
  if UsAuditResponseIndex7 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.seven].answerOption[UsAuditResponseIndex7].extension[0].value.value as Integer
  else
    0

// Question 8
define UsAuditAnswerOptionsQuestion8:
  UsAuditQuestionnaire.item[IndexOfQuestion.eight].answerOption.value.code.value

define CurrentResponse8:
  CurrentResponses R
  where R.id = 'usaudit-question-eight'
  return R.answer

define UsAuditResponseIndex8:
  if Exists(CurrentResponse8) then
    IndexOf(UsAuditAnswerOptionsQuestion8, singleton from CurrentResponse8.code.value as String)
  else
    -1

define UsAuditScoreQuestion8:
  if UsAuditResponseIndex8 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.eight].answerOption[UsAuditResponseIndex8].extension[0].value.value as Integer
  else
    0

// Should Questions #9 and #10 be displayed?
define DisplayUsAuditQuestions9and10:
  (ScoreUsAuditC < ThresholdUsAuditC
    and singleton from CurrentResponse1 !~ "Never"
    and singleton from CurrentResponsePrescreen ~ "Yes"
    and Exists(CurrentResponse2)
    and Exists(CurrentResponse3)
    and HadButDoesNotCurrentlyHaveAlcoholUseDisorder)
  or DisplayUsAuditQuestions4to8

// Question 9
define UsAuditAnswerOptionsQuestion9:
  UsAuditQuestionnaire.item[IndexOfQuestion.nine].answerOption.value.code.value

define CurrentResponse9:
  CurrentResponses R
  where R.id = 'usaudit-question-nine'
  return R.answer

define UsAuditResponseIndex9:
  if Exists(CurrentResponse9) then
    IndexOf(UsAuditAnswerOptionsQuestion9, singleton from CurrentResponse9.code.value as String)
  else
    -1

define UsAuditScoreQuestion9:
  if UsAuditResponseIndex9 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.nine].answerOption[UsAuditResponseIndex9].extension[0].value.value as Integer
  else
    0

// Question 10
define UsAuditAnswerOptionsQuestion10:
  UsAuditQuestionnaire.item[IndexOfQuestion.ten].answerOption.value.code.value

define CurrentResponse10:
  CurrentResponses R
  where R.id = 'usaudit-question-ten'
  return R.answer

define UsAuditResponseIndex10:
  if Exists(CurrentResponse10) then
    IndexOf(UsAuditAnswerOptionsQuestion10, singleton from CurrentResponse10.code.value as String)
  else
    -1

define UsAuditScoreQuestion10:
  if UsAuditResponseIndex10 != -1 then
    UsAuditQuestionnaire.item[IndexOfQuestion.ten].answerOption[UsAuditResponseIndex10].extension[0].value.value as Integer
  else
    0

define AnsweredQuestionsFourThroughEight:
  Exists(CurrentResponse4)
    and Exists(CurrentResponse5)
    and Exists(CurrentResponse6)
    and Exists(CurrentResponse7)
    and Exists(CurrentResponse8)

define AnsweredQuestionsNineAndTen:
  Exists(CurrentResponse9)
    and Exists(CurrentResponse10)

define AnsweredQuestionsFourThroughTen:
  AnsweredQuestionsFourThroughEight
    and AnsweredQuestionsNineAndTen

// Should the score for the Full USAUDIT be displayed?
define DisplayScoreFullUsAudit:
  AnsweredQuestionsFourThroughTen
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full USAUDIT
define ScoreFullUsAudit:
  ScoreUsAuditC
  + UsAuditScoreQuestion4
  + UsAuditScoreQuestion5
  + UsAuditScoreQuestion6
  + UsAuditScoreQuestion7
  + UsAuditScoreQuestion8
  + UsAuditScoreQuestion9
  + UsAuditScoreQuestion10

// Should the pregnancy question be displayed?
define DisplayPregnancyQuestion:
  FemaleAtBirth
    and not IsPregnant
    and not HasHadHysterectomy
    and AgeInYears() between 18 and 49 // 18 <= AgeInYears() < 50
    and ( // This last part is here to ensure that the pregnancy question shows up at the end.
      (AnsweredQuestionsOneThroughThree and not DisplayUsAuditQuestions4to8 and not DisplayUsAuditQuestions9and10) or
      (AnsweredQuestionsOneThroughThree and not DisplayUsAuditQuestions4to8 and AnsweredQuestionsNineAndTen) or
      (AnsweredQuestionsFourThroughTen)
    )
