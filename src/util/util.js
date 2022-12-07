/**
 * Parses a Questionnaire and determines what value choice (value[x]) each of its items are.
 * @param {object} allOrPartQuestionnaire - A FHIR Questionnaire or a subset of its items
 * @param {array} typeHash - An array containing the value choice (value[x]) for each item
 * @returns {array} typeHash - An array containing the value choice (value[x]) for each item
 */
export function getItemTypes(allOrPartQuestionnaire, typeHash) {
  let items = allOrPartQuestionnaire.item;
  items.forEach((itm) => {
    if (itm.type == "group") {
      typeHash = getItemTypes(itm, typeHash); // recursive function call
    } else if (itm.type == "boolean") {
      typeHash[itm.linkId] = "valueBoolean";
    } else {
      typeHash[itm.linkId] = "valueString";
    }
  });
  return typeHash;
}

export function getCurrentISODate() {
  let now = new Date(Date.now()); // Date.now() returns [millisecods]
  let timeZoneCorrection = now.getTimezoneOffset() * 60 * 1000; // [minutes] * [seconds/minutes] * [milliseconds/second]
  let correctedDate = new Date(now.getTime() - timeZoneCorrection);
  return correctedDate.toISOString().split("T")[0]; // just the date portion
}

/*
 * @param dateString in ISO Date short format, e.g. 2022-11-01
 * @return date object in local timezone
 */
export function getCorrectedDateByTimeZone(dateString) {
  if (!dateString) return null;
  let dateObject = new Date(dateString);
  let timeZoneCorrection = dateObject.getTimezoneOffset() * 60 * 1000; // [minutes] * [seconds/minutes] * [milliseconds/second]
  let correctedDate = new Date(dateObject.getTime() + timeZoneCorrection);
  return correctedDate;
}

export function capitalizeFirstLetter(text) {
  if (!text) return "";
  return text[0].toUpperCase() + text.substring(1);
}

export function getObservationCategories() {
  return [
    "social-history",
    "vital-signs",
    "imaging",
    "laboratory",
    "procedure",
    "survey",
    "exam",
    "therapy",
    "activity",
  ];
}

export function getResponseValue(questionnaire, linkId, response) {
  let responseValue = {};
  let questionItemIndex = questionnaire.item.findIndex(
    (itm) => itm.linkId == linkId
  );
  let item = questionnaire.item[questionItemIndex];
  if (item.type == "choice") {
    let answerOptionIndex = item.answerOption.findIndex((itm) => {
      if (itm.valueString && itm.valueString == response) return true;
      if (itm.valueCoding && itm.valueCoding.display == response) return true;
      return false;
    });
    if (item.answerOption[answerOptionIndex].valueString) {
      responseValue.type = "valueString";
      responseValue.value = response;
    } else if (item.answerOption[answerOptionIndex].valueCoding) {
      responseValue.type = "valueCoding";
      responseValue.value = item.answerOption[answerOptionIndex].valueCoding;
    } // TODO: ELSE THROW ERROR
  } else if (item.type == "boolean") {
    responseValue.type = "valueBoolean";
    responseValue.value = response;
  } else if (item.type == "decimal") {
    responseValue.type = "valueDecimal";
    responseValue.value = !isNaN(response) ? parseFloat(response) : response;
  } else {
    responseValue.type = "valueCoding";
    responseValue.value = { display: response };
  }

  return responseValue;
}

export function getFHIRResourcePaths(patientId) {
  if (!patientId) return [];
  const envFHIRResources = getEnv("VUE_APP_FHIR_RESOURCES");
  const envObCategories = getEnv("VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES");
  let resources = envFHIRResources ? envFHIRResources.split(",") : [];
  const hasQuestionnaireResponses = resources.filter(
    (item) => item.toLowerCase() === "questionnaireresponse"
  ).length > 0;
  if (!hasQuestionnaireResponses) {
    // load questionnaire response(s) by default
    resources.push("QuestionnaireResponse");
  }
  return resources.map((resource) => {
    let path = `/${resource}?patient=${patientId}`;
    if (
      resource.toLowerCase() === "observation" &&
      envObCategories &&
      envObCategories.toLowerCase() === "true"
    ) {
      path =
        path +
        "&" +
        encodeURIComponent(
          getObservationCategories()
            .map((cat) => "category=" + cat)
            .join("&")
        );
    }
    return path;
  });
}

export function fetchEnvData() {
  if (window["appConfig"] && Object.keys(window["appConfig"]).length) {
    console.log("Window config variables added. ");
    return;
  }
  const setConfig = function() {
    if (!xhr.readyState === xhr.DONE) {
      return;
    }
    if (xhr.status !== 200) {
      console.log("Request failed! ");
      return;
    }
    var envObj = JSON.parse(xhr.responseText);
    window["appConfig"] = {};
    //assign window process env variables for access by app
    //won't be overridden when Node initializing env variables
    for (var key in envObj) {
      if (!window["appConfig"][key]) {
        window["appConfig"][key] = envObj[key];
      }
    }
  };
  var xhr = new XMLHttpRequest();
  xhr.open("GET", "/env.json", false);
  xhr.onreadystatechange = function() {
    //in the event of a communication error (such as the server going down),
    //or error happens when parsing data
    //an exception will be thrown in the onreadystatechange method when accessing the response properties, e.g. status.
    try {
      setConfig();
    } catch (e) {
      console.log("Caught exception " + e);
    }
  };
  try {
    xhr.send();
  } catch (e) {
    console.log("Request failed to send.  Error: ", e);
  }
  xhr.ontimeout = function(e) {
    // XMLHttpRequest timed out.
    console.log("request to fetch env.json file timed out ", e);
  };
}

export function getEnv(key) {
  //window application global variables
  if (window["appConfig"] && window["appConfig"][key])
    return window["appConfig"][key];
  const envDefined = typeof process !== "undefined" && process.env;
  //enviroment variables as defined in Node
  if (envDefined && process.env[key]) return process.env[key];
  return "";
}

export function getEnvs() {
  const appConfig = window["appConfig"] ? window["appConfig"] : {};
  const processEnvs = process.env ? process.env : {};
  return {
    ...appConfig,
    ...processEnvs,
  };
}

export function getErrorText(error) {
  if (!error) return "";
  if (typeof error === "object") {
    if (error.message) return error.message;
    return error.toString();
  }
  return error;
}

export function imageOK(img) {
  if (!img) {
    return false;
  }
  if (!img.getAttribute("src")) {
    return false;
  }
  if (!img.complete) {
    return false;
  }
  if (typeof img.naturalWidth !== "undefined" && img.naturalWidth === 0) {
    return false;
  }
  return true;
}

export function setFavicon(href) {
  if (!href) return;
  let faviconEl = document.querySelector("link[rel*='icon']");
  if (!faviconEl) return;
  faviconEl.href = href;
}

export function removeArrayItem (arr, value) {
  if (!arr || !Array.isArray(arr)) return [];
  let index = arr.indexOf(value);
  if (index > -1) {
    arr.splice(index, 1);
  }
  return arr;
}

export const queryPatientIdKey = "launch_queryPatientId";
