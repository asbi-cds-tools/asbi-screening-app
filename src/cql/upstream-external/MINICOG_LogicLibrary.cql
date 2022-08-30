library MinicogLogicLibrary version '1.0.0'

using FHIR version '4.0.1'

include "FHIRHelpers" version '4.0.1' called FHIRHelpers

// -----------------------------------------------------------------------------
// PARAMETERS
// -----------------------------------------------------------------------------
parameter DisplayScreeningScores default true
parameter QuestionnaireURL default 'http://www.cdc.gov/ncbddd/fasd/minicog'


//question link ids
define question1LinkId: 'minicog-question1'
define question2LinkId: 'minicog-question2'


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
define MiniCogQuestionnaire:
  singleton from ([Questionnaire] Q
    where Q.url.value = CurrentQuestionnaireURL)

// Load Questionnaire responses
define QuestionnaireResponses:
  ([QuestionnaireResponse] QR
    where (QR.questionnaire.value = CurrentQuestionnaireURL or
    PositionOf(MiniCogQuestionnaire.id, QR.questionnaire.value)  != -1)
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
    answer: I.answer[0].value // Assuming only one answer per question
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
  return
    case
      when CR is null then 0
      when CR.answer is not null then CR.answer.value
      else 0
    end

/* 
 * @param qId, question id, e.g. linkId
 * @return answer for the question
 */
define function getQuestionScore(qId String):
  First(
   getCurrentResponseByQuestionId(qId)
  )

define question1Response:
  getCurrentResponseByQuestionId(question1LinkId)
define question2Response:
  getCurrentResponseByQuestionId(question2LinkId)
define question1Score:
  getQuestionScore(question1LinkId)
define question2Score:
  getQuestionScore(question2LinkId)

// Should the score for the Full MiniCog be displayed?
define DisplayScoreFullMiniCog:
   (
    exists(question1Response) and 
    exists(question2Response)
   ) // at least one response for all the questions
    and DisplayScreeningScores // Input parameter which allows score display to be disabled

// Question 1 score
define miniCogScoreQuestion1:
  question1Score score
  return
    case
      when score is null then 0
      else score
    end

// Question 2 score
define miniCogScoreQuestion2:
  question2Score score
  return
    case
      when score is null then 0
      else score
    end

// Calculate the score for the Full MiniCog
// sum up numeric values for all the answers
// question 1 score + question 2 score if available
// otherwise question 1 score or question 2 score if either is available
// lastly return 0 if none available
define ScoreFullMiniCog:
    miniCogScoreQuestion1+miniCogScoreQuestion2
