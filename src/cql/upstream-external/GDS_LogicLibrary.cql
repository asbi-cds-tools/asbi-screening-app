library GdsLogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// CODESYSTEMS, VALUE SETS, CODES, AND CONCEPTS
// -----------------------------------------------------------------------------

codesystem "LOINC": 'http://loinc.org'
codesystem "LOCAL": 'http://www.cdc.gov/ncbddd/fasd'


// Local (non-standard) codes
// Not sure if this qualifies as LOCAL...
code "Gds Total Score code": '48545-8' from "LOCAL" display 'Gds Total Score'

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireName default 'gds'
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/gds'

define question1LinkId: '/48512-8'
define question2LinkId: '/48513-6'
define question3LinkId: '/48514-4'
define question4LinkId: '/48515-1'
define question5LinkId: '/48518-5'
define question6LinkId: '/48519-3'
define question7LinkId: '/48520-1'
define question8LinkId: '/48521-9'
define question9LinkId: '/48523-5'
define question10LinkId: '/48525-0'
define question11LinkId: '/48526-8'
define question12LinkId: '/48528-4'
define question13LinkId: '/48532-6'
define question14LinkId: '/48533-4'
define question15LinkId: '/48534-2'

// -----------------------------------------------------------------------------
// PATIENT INFORMATION
// -----------------------------------------------------------------------------
context Patient

// We need to set the QuestionnaireURL parameter to an expression before we can use it
define CurrentQuestionnaireURL:
  QuestionnaireURL

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

//------------------------------------------------------------------------------
// QUESTIONNAIRE AND QUESTIONNAIRERESPONSE LOGIC
//------------------------------------------------------------------------------

// Load Questionnaire
define GDSQuestionnaire:
  singleton from ([Questionnaire] Q
    where (
      Q.url.value = CurrentQuestionnaireURL or
      PositionOf(Lower(QuestionnaireName), Lower(Q.id)) != -1 or
      Lower(Q.name) = Lower(QuestionnaireName)
    ))

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  GDSQuestionnaire Q
  let item: Q.item
  return item.linkId.value

// Determine the index of each question based upon the extracted link ID
define IndexOfQuestion:
  {
    one: IndexOf(ItemLinkIds, question1LinkId),
    two: IndexOf(ItemLinkIds, question2LinkId),
    three: IndexOf(ItemLinkIds, question3LinkId),
    four: IndexOf(ItemLinkIds, question4LinkId),
    five: IndexOf(ItemLinkIds, question5LinkId),
    six: IndexOf(ItemLinkIds, question6LinkId),
    seven: IndexOf(ItemLinkIds, question7LinkId),
    eight: IndexOf(ItemLinkIds, question8LinkId),
    nine: IndexOf(ItemLinkIds, question9LinkId),
    ten: IndexOf(ItemLinkIds, question10LinkId),
    eleven: IndexOf(ItemLinkIds, question11LinkId),
    twelve: IndexOf(ItemLinkIds, question12LinkId),
    thirteen: IndexOf(ItemLinkIds, question13LinkId),
    fourteen: IndexOf(ItemLinkIds, question14LinkId),
    fifteen: IndexOf(ItemLinkIds, question15LinkId)
  }

define QuestionnaireResponses:
  ([QuestionnaireResponse] QR
    where (
      QR.questionnaire.value = CurrentQuestionnaireURL or
      PositionOf(GDSQuestionnaire.id, QR.questionnaire.value)  != -1)
    sort by authored desc
  )

// Load the QuestionnaireResponse currently being filled out
define CurrentQuestionnaireResponse:
  singleton from (QuestionnaireResponses QR
    where date from QR.authored.value >= Today()
      and QR.status.value = 'in-progress'
  )

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

/*
 @param question linkId of type FHIR.String
 @return answer element with that linkId
 */
define function getCurrentResponseByQuestionId(qid String):
  (
    CurrentResponses R
    where R.id = qid
  ) CR 
  return if CR is not null then CR.answer else null

/*
 retrieve concept code of the selected answer option
 @param question index of type FHIR.Integer
 @return code value for the answer
 */
define function getAnswerOptionCodeValue(qIndex Integer):
  if GDSQuestionnaire.item[qIndex] is not null then
    GDSQuestionnaire.item[qIndex].answerOption.value.code.value
  else
    null

/*
 * retrieve the numeric value for the answer from extension
 * @param a list of elements of type FHIR.Extension
 * @return the value as Integer
 */
define function getAnswerOptionExtensionValue(extList List<FHIR.Extension>):
  (extList e where e.url ~ 'http://hl7.org/fhir/StructureDefinition/ordinalValue')[0].value.value as Integer

/* @param qIndex, question index,
 * @param qId, question id, e.g. linkId
 * @return score for the question
 */
define function getQuestionScore(qIndex Integer, qId String):
    (getCurrentResponseByQuestionId(qId)[0]) qResponse
    let
      qAnswerOptionCode: getAnswerOptionCodeValue(qIndex),
      qResponseIndex: if qResponse is not null then IndexOf(qAnswerOptionCode, qResponse.code.value as String) else -1,
      extensionItem: GDSQuestionnaire.item[qIndex].answerOption[qResponseIndex].extension
    return
      if qResponseIndex != -1 then
        if extensionItem is not null then
          getAnswerOptionExtensionValue(extensionItem)
        else null
      else
        null
      
// Question 1, one point for answering no
define GdsScoreQuestion1:
  (getQuestionScore(IndexOfQuestion.one, question1LinkId)) score
  return
    if score is null then 0
    else if score = 1 then 0
    else 1

// Question 2, one point for answering yes
define GdsScoreQuestion2:
  (getQuestionScore(IndexOfQuestion.two, question2LinkId)) score
  return 
    if score is null then 0
    else score

// Question 3, one point for answering yes
define GdsScoreQuestion3:
  (getQuestionScore(IndexOfQuestion.three, question3LinkId)) score
  return
    if score is null then 0
    else score

// Question 4, one point for answering yes
define GdsScoreQuestion4:
  (getQuestionScore(IndexOfQuestion.four, question4LinkId)) score
  return
    if score is null then 0
    else score

// Question 5, one point for answering no
define GdsScoreQuestion5:
  (getQuestionScore(IndexOfQuestion.five, question5LinkId)) score
  return
    if score is null then 0
    else if score = 1 then 0
    else 1

// Question 6, one point for answering yes
define GdsScoreQuestion6:
  (getQuestionScore(IndexOfQuestion.six, question6LinkId)) score
  return
    if score is null then 0
    else score

// Question 7, one point for answering no
define GdsScoreQuestion7:
  (getQuestionScore(IndexOfQuestion.seven, question7LinkId)) score
  return
    if score is null then 0
    else if score = 1 then 0
    else 1

// Question 8, one point for answering yes
define GdsScoreQuestion8:
  (getQuestionScore(IndexOfQuestion.eight, question8LinkId)) score
  return
    if score is null then 0
    else score

// Question 9, one point for answering yes
define GdsScoreQuestion9:
  (getQuestionScore(IndexOfQuestion.nine, question9LinkId)) score
  return
    if score is null then 0
    else score

// Question 10, one point for answering yes
define GdsScoreQuestion10:
  (getQuestionScore(IndexOfQuestion.ten, question10LinkId)) score
  return
    if score is null then 0
    else score

// Question 11, one point for answering no
define GdsScoreQuestion11:
  (getQuestionScore(IndexOfQuestion.eleven, question11LinkId)) score
  return
    if score is null then 0
    else if score = 1 then 0
    else 1

// Question 12, one point for answering yes
define GdsScoreQuestion12:
  (getQuestionScore(IndexOfQuestion.twelve, question12LinkId)) score
  return
    if score is null then 0
    else score

// Question 13, one point for answering no
define GdsScoreQuestion13:
  (getQuestionScore(IndexOfQuestion.thirteen, question13LinkId)) score
  return
    if score is null then 0
    else if score = 1 then 0
    else 1

// Question 14, one point for answering yes
define GdsScoreQuestion14:
  (getQuestionScore(IndexOfQuestion.fourteen, question14LinkId)) score
  return
    if score is null then 0
    else score

// Question 15, one point for answering yes
define GdsScoreQuestion15:
  (getQuestionScore(IndexOfQuestion.fifteen, question15LinkId)) score
  return
    if score is null then 0
    else score

// Should the score for the Full Gds be displayed?
define DisplayScoreFullGds:
   (
    (getCurrentResponseByQuestionId(question1LinkId)) is not null or 
    (getCurrentResponseByQuestionId(question2LinkId)) is not null or
    (getCurrentResponseByQuestionId(question3LinkId)) is not null or
    (getCurrentResponseByQuestionId(question4LinkId)) is not null or 
    (getCurrentResponseByQuestionId(question5LinkId)) is not null or
    (getCurrentResponseByQuestionId(question6LinkId)) is not null or
    (getCurrentResponseByQuestionId(question7LinkId)) is not null or
    (getCurrentResponseByQuestionId(question8LinkId)) is not null or
    (getCurrentResponseByQuestionId(question9LinkId)) is not null or
    (getCurrentResponseByQuestionId(question10LinkId)) is not null or
    (getCurrentResponseByQuestionId(question11LinkId)) is not null or
    (getCurrentResponseByQuestionId(question12LinkId)) is not null or
    (getCurrentResponseByQuestionId(question13LinkId)) is not null or
    (getCurrentResponseByQuestionId(question14LinkId)) is not null or
    (getCurrentResponseByQuestionId(question15LinkId)) is not null
   ) // at least one response for all the questions
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full Gds
// sum up all numeric values for all the answers
define ScoreFullGds:
  Coalesce(GdsScoreQuestion1, 0)
  + Coalesce(GdsScoreQuestion2, 0)
  + Coalesce(GdsScoreQuestion3, 0)
  + Coalesce(GdsScoreQuestion4, 0)
  + Coalesce(GdsScoreQuestion5, 0)
  + Coalesce(GdsScoreQuestion6, 0)
  + Coalesce(GdsScoreQuestion7, 0)
  + Coalesce(GdsScoreQuestion8, 0)
  + Coalesce(GdsScoreQuestion9, 0)
  + Coalesce(GdsScoreQuestion10, 0)
  + Coalesce(GdsScoreQuestion11, 0)
  + Coalesce(GdsScoreQuestion12, 0)
  + Coalesce(GdsScoreQuestion13, 0)
  + Coalesce(GdsScoreQuestion14, 0)
  + Coalesce(GdsScoreQuestion15, 0)
