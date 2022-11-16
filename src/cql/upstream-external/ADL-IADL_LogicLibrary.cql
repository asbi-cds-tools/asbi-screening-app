library ADL_IADLLogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers


// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireName default 'adl-iadl'
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/adl-iadl'

define question1LinkId: '/46595-5'
define question2LinkId: '/46597-1'
define question3LinkId: '/46599-7'
define question4LinkId: '/57243-8'
define question5LinkId: '/57244-6'
define question6LinkId: '/57245-3'
define question7LinkId: '/57246-1'
define question8LinkId: '/57247-9'
define question9LinkId: '/57248-7'
define question10LinkId: '/57249-5'
define question11LinkId: '/46569-0'

// -----------------------------------------------------------------------------
// PATIENT INFORMATION
// -----------------------------------------------------------------------------
context Patient

// We need to set the QuestionnaireURL parameter to an expression before we can use it
define CurrentQuestionnaireURL:
  QuestionnaireURL

//------------------------------------------------------------------------------
// QUESTIONNAIRE AND QUESTIONNAIRERESPONSE LOGIC
//------------------------------------------------------------------------------

// Load Questionnaire
define ADL_IADL_Questionnaire:
  singleton from ([Questionnaire] Q
    where (
      Q.url.value = CurrentQuestionnaireURL or
      PositionOf(Lower(QuestionnaireName), Lower(Q.id)) != -1 or
      Lower(Q.name) = Lower(QuestionnaireName)
    ))

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  ADL_IADL_Questionnaire Q
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
    eleven: IndexOf(ItemLinkIds, question11LinkId)
  }

define QuestionnaireResponses:
  ([QuestionnaireResponse] QR
    where (
      QR.questionnaire.value = CurrentQuestionnaireURL or
      PositionOf(ADL_IADL_Questionnaire.id, QR.questionnaire.value)  != -1)
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
  if ADL_IADL_Questionnaire.item[qIndex] is not null then
    ADL_IADL_Questionnaire.item[qIndex].answerOption.value.code.value
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
      extensionItem: ADL_IADL_Questionnaire.item[qIndex].answerOption[qResponseIndex].extension
    return
      if qResponseIndex != -1 then
        if extensionItem is not null then
          getAnswerOptionExtensionValue(extensionItem)
        else null
      else
        null
      
// Question 1
define ADL_IADL_ScoreQuestion1:
  (getQuestionScore(IndexOfQuestion.one, question1LinkId)) score
  return
    if score is null then 0
    else score

// Question 2
define ADL_IADL_ScoreQuestion2:
  (getQuestionScore(IndexOfQuestion.two, question2LinkId)) score
  return 
    if score is null then 0
    else score

// Question 3
define ADL_IADL_ScoreQuestion3:
  (getQuestionScore(IndexOfQuestion.three, question3LinkId)) score
  return
    if score is null then 0
    else score

// Question 4
define ADL_IADL_ScoreQuestion4:
  (getQuestionScore(IndexOfQuestion.four, question4LinkId)) score
  return
    if score is null then 0
    else score

// Question 5
define ADL_IADL_ScoreQuestion5:
  (getQuestionScore(IndexOfQuestion.five, question5LinkId)) score
  return
    if score is null then 0
    else score

// Question 6
define ADL_IADL_ScoreQuestion6:
  (getQuestionScore(IndexOfQuestion.six, question6LinkId)) score
  return
    if score is null then 0
    else score

// Question 7
define ADL_IADL_ScoreQuestion7:
  (getQuestionScore(IndexOfQuestion.seven, question7LinkId)) score
  return
    if score is null then 0
    else score

// Question 8
define ADL_IADL_ScoreQuestion8:
  (getQuestionScore(IndexOfQuestion.eight, question8LinkId)) score
  return
    if score is null then 0
    else score

// Question 9
define ADL_IADL_ScoreQuestion9:
  (getQuestionScore(IndexOfQuestion.nine, question9LinkId)) score
  return
    if score is null then 0
    else score

// Question 10
define ADL_IADL_ScoreQuestion10:
  (getQuestionScore(IndexOfQuestion.ten, question10LinkId)) score
  return
    if score is null then 0
    else score

// Question 11
define ADL_IADL_ScoreQuestion11:
  (getQuestionScore(IndexOfQuestion.eleven, question11LinkId)) score
  return
    if score is null then 0
    else score


// Should the score for the Full ADL_IADL be displayed?
define DisplayScoreFullADL_IADL:
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
    (getCurrentResponseByQuestionId(question11LinkId)) is not null
   ) // at least one response for all the questions
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full ADL_IADL
// sum up all numeric values for all the answers
define ScoreFullADL_IADL:
  Coalesce(ADL_IADL_ScoreQuestion1, 0)
  + Coalesce(ADL_IADL_ScoreQuestion2, 0)
  + Coalesce(ADL_IADL_ScoreQuestion3, 0)
  + Coalesce(ADL_IADL_ScoreQuestion4, 0)
  + Coalesce(ADL_IADL_ScoreQuestion5, 0)
  + Coalesce(ADL_IADL_ScoreQuestion6, 0)
  + Coalesce(ADL_IADL_ScoreQuestion7, 0)
  + Coalesce(ADL_IADL_ScoreQuestion8, 0)
  + Coalesce(ADL_IADL_ScoreQuestion9, 0)
  + Coalesce(ADL_IADL_ScoreQuestion10, 0)
  + Coalesce(ADL_IADL_ScoreQuestion11, 0)
