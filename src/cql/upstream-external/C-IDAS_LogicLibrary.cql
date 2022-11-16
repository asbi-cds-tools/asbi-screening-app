library CIDASLogicLibrary version '1.0.0'
/* Change Log
*/

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireName default 'c-idas'
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/c-idas'

define question1LinkId: 'cs-idas-1'
define question2LinkId: 'cs-idas-2'
define question3LinkId: 'cs-idas-3'
define question4LinkId: 'cs-idas-4'
define question5LinkId: 'cs-idas-5'
define question6LinkId: 'cs-idas-6'
define question7LinkId: 'cs-idas-7'
define question8LinkId: 'cs-idas-8'
define question9LinkId: 'cs-idas-9'
define question10LinkId: 'cs-idas-10'
define question11LinkId: 'cs-idas-11'
define question12LinkId: 'cs-idas-12'
define question13LinkId: 'cs-idas-13'
define question14LinkId: 'cs-idas-14'
define question15LinkId: 'cs-idas-15'
define question16LinkId: 'cs-idas-16'
define question17LinkId: 'cs-idas-17'
define question18LinkId: 'cs-idas-18'


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
define CIDASQuestionnaire:
  singleton from ([Questionnaire] Q
    where (
      Q.url.value = CurrentQuestionnaireURL or
      PositionOf(Lower(QuestionnaireName), Lower(Q.id)) != -1 or
      Lower(Q.name) = Lower(QuestionnaireName)
    ))

// Extract of the link IDs of each item in the Questionnaire
define ItemLinkIds:
  CIDASQuestionnaire Q
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
    fifteen: IndexOf(ItemLinkIds, question15LinkId),
    sixteen: IndexOf(ItemLinkIds, question16LinkId),
    seventeen: IndexOf(ItemLinkIds, question17LinkId),
    eighteen: IndexOf(ItemLinkIds, question18LinkId)
  }

define QuestionnaireResponses:
  ([QuestionnaireResponse] QR
    where (
      QR.questionnaire.value = CurrentQuestionnaireURL or
      PositionOf(CIDASQuestionnaire.id, QR.questionnaire.value)  != -1)
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
  if CIDASQuestionnaire.item[qIndex] is not null then
    CIDASQuestionnaire.item[qIndex].answerOption.value.code.value
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
      extensionItem: CIDASQuestionnaire.item[qIndex].answerOption[qResponseIndex].extension
    return
      if qResponseIndex != -1 then
        if extensionItem is not null then
          getAnswerOptionExtensionValue(extensionItem)
        else null
      else
        null
      
// Question 1
define CIDASScoreQuestion1:
  (getQuestionScore(IndexOfQuestion.one, question1LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 2
define CIDASScoreQuestion2:
  (getQuestionScore(IndexOfQuestion.two, question2LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 3
define CIDASScoreQuestion3:
  (getQuestionScore(IndexOfQuestion.three, question3LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 4
define CIDASScoreQuestion4:
  (getQuestionScore(IndexOfQuestion.four, question4LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 5
define CIDASScoreQuestion5:
  (getQuestionScore(IndexOfQuestion.five, question5LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 6
define CIDASScoreQuestion6:
  (getQuestionScore(IndexOfQuestion.six, question6LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer


// Question 7
define CIDASScoreQuestion7:
  (getQuestionScore(IndexOfQuestion.seven, question7LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 8
define CIDASScoreQuestion8:
  (getQuestionScore(IndexOfQuestion.eight, question8LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 9
define CIDASScoreQuestion9:
  (getQuestionScore(IndexOfQuestion.nine, question9LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 10
define CIDASScoreQuestion10:
  (getQuestionScore(IndexOfQuestion.ten, question10LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 11
define CIDASScoreQuestion11:
  (getQuestionScore(IndexOfQuestion.eleven, question11LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 12
define CIDASScoreQuestion12:
  (getQuestionScore(IndexOfQuestion.twelve, question12LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 13
define CIDASScoreQuestion13:
  (getQuestionScore(IndexOfQuestion.thirteen, question13LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 14
define CIDASScoreQuestion14:
  (getQuestionScore(IndexOfQuestion.fourteen, question14LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 15
define CIDASScoreQuestion15:
  (getQuestionScore(IndexOfQuestion.fifteen, question15LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 16
define CIDASScoreQuestion16:
  (getQuestionScore(IndexOfQuestion.sixteen, question16LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 17
define CIDASScoreQuestion17:
  (getQuestionScore(IndexOfQuestion.seventeen, question17LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Question 18
define CIDASScoreQuestion18:
  (getQuestionScore(IndexOfQuestion.eighteen, question18LinkId)) score
  return
    if score = 'a' then 0
    else if score is null then 0
    else score as Integer

// Should the score for the Full C-IDAS be displayed?
define DisplayScoreFullCIDAS:
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
    (getCurrentResponseByQuestionId(question15LinkId)) is not null or
    (getCurrentResponseByQuestionId(question16LinkId)) is not null or
    (getCurrentResponseByQuestionId(question17LinkId)) is not null or
    (getCurrentResponseByQuestionId(question18LinkId)) is not null

   ) // at least one response for all the questions
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Calculate the score for the Full C-IDAS
// sum up all numeric values for all the answers
define ScoreFullCIDAS:
  CIDASScoreQuestion1
  + CIDASScoreQuestion2
  + CIDASScoreQuestion3
  + CIDASScoreQuestion4
  + CIDASScoreQuestion5
  + CIDASScoreQuestion6
  + CIDASScoreQuestion7
  + CIDASScoreQuestion8
  + CIDASScoreQuestion9
  + CIDASScoreQuestion10
  + CIDASScoreQuestion11
  + CIDASScoreQuestion12
  + CIDASScoreQuestion13
  + CIDASScoreQuestion14
  + CIDASScoreQuestion15
  + CIDASScoreQuestion16
  + CIDASScoreQuestion17
  + CIDASScoreQuestion18
