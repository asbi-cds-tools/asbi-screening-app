import { getEnv } from "./util";

function getDefaultLogObject() {
  return {
    level: "info",
    tags: ["screener-front-end"],
    systemURL: window.location.href,
    deployment: getEnv("VUE_APP_SYSTEM_TYPE"),
    message: {}
  }
}
//write to audit log
// @param level, expect string
// @param tags, expect array, e.g. ['etc'],
// @param body, log main body content, expect object, e.g. {subect: "Patient/12"}
// @param message, expect object, e.g. { "questionId": "123"}
export function writeToLog(level, tags, body, message) {
  const confidentialBackendURL = getEnv("VUE_APP_CONF_API_URL");
  if (!confidentialBackendURL) {
    console.log("audit log skipped; confidential backend URL is not set");
    return;
  }
  let postBody = {
    ...getDefaultLogObject(),
    ...body};
  if (level) postBody.level = level;
  if (tags) postBody.tags = [...postBody.tags, ...tags];
  if (message)
    postBody.message = {
      ...postBody.message,
      ...message,
    };
  const auditURL = `${confidentialBackendURL || ""}/auditlog`;
  fetch(auditURL, {
    method: "post",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(postBody),
  })
    .then((response) => {
      if (!response.ok) {
        throw Error(response.statusText);
      }
      return response.json();
    })
    .then(function (data) {
      console.log("audit request succeeded with response ", data);
    })
    .catch(function (error) {
      console.log("Request failed", error);
    });
}

// write to log on survey page change event
// @param options, see options object available on SurveyJS onCurrentPageChanged event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onCurrentPageChanged
// @param logBody, expect object, main log body content
// @param messageParams, of type object, optional, additional params post to log server
export function writeLogOnSurveyPageChange(options, logBody, messageParams) {
  if (!options) return;
  const questionElements = options.oldCurrentPage
    ? options.oldCurrentPage.questions
    : null;
  if (!questionElements) {
    return;
  }
  messageParams = messageParams || {};
  let arrVisibleQuestions = questionElements
    .filter((q) => q.isVisible)
    .map((q) => q.name);
  // whether user clicks the previous or next button
  const navDirection = options.isNextPage
    ? "clickNext"
    : options.isPrevPage
    ? "clickPrev"
    : "";
  if (arrVisibleQuestions.length) {
    writeToLog("info", ["questionDisplayed", "onPageChanged", navDirection], logBody, {
      questionID: arrVisibleQuestions,
      ...messageParams,
    });
  }
}

// write to log on survey page rendered event
// @param options, see options object available on SurveyJS onAfterRenderPage event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onAfterRenderPage
// @param logBody, expect object, main log body content
// @param messageParams, of type object, optional, additional params post to log server
export function writeLogOnSurveyPageRendered(options, logBody, messageParams) {
  if (!options) return;
  const questionElements = options.page ?
    options.page.questions
    : null;
  if (!questionElements) {
    return;
  }
  messageParams = messageParams || {};
  let arrVisibleQuestions = questionElements
    .filter((q) => q.isVisible)
    .map((q) => q.name);
  if (arrVisibleQuestions.length) {
    writeToLog("info", ["questionDisplayed", "onPageRendered"], logBody, {
      questionID: arrVisibleQuestions,
      ...messageParams,
    });
  }
}
// write to log on survey question value change event
// @param options, see options object available on SurveyJS onValueChanging event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onValueChanging
// @param logBody, expect object, main log body content
// @param messageParams, of type object, optional, additional params post to log server
export function writeLogOnSurveyQuestionValueChange(options, logBody, messageParams) {
  if (!options) return;
  messageParams = messageParams || {};
  writeToLog("info", ["answerEvent"], logBody, {
    questionId: options.name,
    answerEntered: options.value,
    ...messageParams,
  });
}

// write to log on survey completing
// @params sender, see sender object available on SurveyJs OnComplete event
// https://surveyjs.io/form-library/documentation/api-reference/surveymodel#onComplete
// @param logBody, expect object, main log body content
// @param messageParams, of type object, optional, additional params post to log server
export function writeLogOnSurveySubmit(logBody, messageParams) {
    writeToLog("info", ["onSubmit"], logBody, messageParams);
}
