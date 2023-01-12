library CP_ECOGLogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireName default 'cp-ecog'
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/cp-ecog'

define question1LinkId: '/89286-9/89146-5'
define question2LinkId: '/89286-9/89149-9'
define question3LinkId: '/89287-7/89172-1'
define question4LinkId: '/89287-7/89138-2'
define question5LinkId: '/89288-5/89154-9'
define question6LinkId: '/89288-5/89165-5'
define question7LinkId: '/89289-3/89143-2'
define question8LinkId: '/89289-3/89140-8'
define question9LinkId: '/89290-1/89158-0'
define question10LinkId: '/89290-1/89173-9'
define question11LinkId: '/89285-1/89141-6'
define question12LinkId: '/89285-1/89171-3'


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
define ECOG12Questionnaire:
  singleton from ([Questionnaire] Q
    where (
      Q.url.value = CurrentQuestionnaireURL or
      PositionOf(Lower(QuestionnaireName), Lower(Q.id)) != -1 or
      Lower(Q.name) = Lower(QuestionnaireName)
    ))

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  ECOG12Questionnaire Q
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
    twelve: IndexOf(ItemLinkIds, question12LinkId)
  }

define QuestionnaireResponses:
  ([QuestionnaireResponse] QR
    where (
      QR.questionnaire.value = CurrentQuestionnaireURL or
      PositionOf(ECOG12Questionnaire.id, QR.questionnaire.value)  != -1)
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
  if ECOG12Questionnaire.item[qIndex] is not null then
    ECOG12Questionnaire.item[qIndex].answerOption.value.code.value
  else
    null

/*
 * retrieve the numeric value for the answer from extension
 * @param a list of elements of type FHIR.Extension
 * @return the value as Integer
 */
define function getAnswerOptionExtensionValue(extList List<FHIR.Extension>):
  (extList e where e.url ~ 'http://hl7.org/fhir/StructureDefinition/ordinalValue')[0].value.value

/* @param qIndex, question index,
 * @param qId, question id, e.g. linkId
 * @return score for the question
 */
define function getQuestionScore(qIndex Integer, qId String):
    (getCurrentResponseByQuestionId(qId)[0]) qResponse
    let
      qAnswerOptionCode: getAnswerOptionCodeValue(qIndex),
      qResponseIndex: if qResponse is not null then IndexOf(qAnswerOptionCode, qResponse.code.value as String) else -1,
      extensionItem: ECOG12Questionnaire.item[qIndex].answerOption[qResponseIndex].extension
    return
      if qResponseIndex != -1 then
        if extensionItem is not null then
          getAnswerOptionExtensionValue(extensionItem)
        else null
      else
        null
      
// Question 1
define ECOG12ScoreQuestion1:
  (getQuestionScore(IndexOfQuestion.one, question1LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 2
define ECOG12ScoreQuestion2:
  (getQuestionScore(IndexOfQuestion.two, question2LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 3
define ECOG12ScoreQuestion3:
  (getQuestionScore(IndexOfQuestion.three, question3LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 4
define ECOG12ScoreQuestion4:
  (getQuestionScore(IndexOfQuestion.four, question4LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 5
define ECOG12ScoreQuestion5:
  (getQuestionScore(IndexOfQuestion.five, question5LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 6
define ECOG12ScoreQuestion6:
  (getQuestionScore(IndexOfQuestion.six, question6LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer


// Question 7
define ECOG12ScoreQuestion7:
  (getQuestionScore(IndexOfQuestion.seven, question7LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 8
define ECOG12ScoreQuestion8:
  (getQuestionScore(IndexOfQuestion.eight, question8LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 9
define ECOG12ScoreQuestion9:
  (getQuestionScore(IndexOfQuestion.nine, question9LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 10
define ECOG12ScoreQuestion10:
  (getQuestionScore(IndexOfQuestion.ten, question10LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 11
define ECOG12ScoreQuestion11:
  (getQuestionScore(IndexOfQuestion.eleven, question11LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Question 12
define ECOG12ScoreQuestion12:
  (getQuestionScore(IndexOfQuestion.twelve, question12LinkId)) score
  return
    if score = 9 then 0
    else if score is null then 0
    else score as Integer

// Should the score for the Full CP-ECOG be displayed?
define DisplayScoreFullECOG12:
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
    (getCurrentResponseByQuestionId(question12LinkId)) is not null

   ) // at least one response for all the questions
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full CP-ECOG
// sum up all numeric values for all the answers
define ScoreFullECOG12:
  ECOG12ScoreQuestion1
  + ECOG12ScoreQuestion2
  + ECOG12ScoreQuestion3
  + ECOG12ScoreQuestion4
  + ECOG12ScoreQuestion5
  + ECOG12ScoreQuestion6
  + ECOG12ScoreQuestion7
  + ECOG12ScoreQuestion8
  + ECOG12ScoreQuestion9
  + ECOG12ScoreQuestion10
  + ECOG12ScoreQuestion11
  + ECOG12ScoreQuestion12
