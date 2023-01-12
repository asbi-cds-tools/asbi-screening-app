import valueSetJson from "../cql/valueset-db.json";
import { applyDefinition } from "./apply";
import { getEnv, getErrorText } from "./util.js";

export async function getPatientCarePlan(client, patientId) {
  if (!client || !patientId) return null;
  const carePlan = await client
    .request(
      `CarePlan?subject=Patient/${patientId}&category:text=questionnaire&_sort=-_lastUpdated`
    )
    .catch((e) => console.log("Error retrieving patient careplan ", e));
  if (carePlan && carePlan.entry && carePlan.entry.length) {
    return carePlan;
  }

  return null;
}

export async function getQuestionnaireResponsesForPatient(client, patientId) {
  if (!client || !patientId) return null;
  // we need fresh data
  const questionnaireResponsesResult = await client
    .request({
      url: `QuestionnaireResponse?patient=${patientId}`,
      headers: {
        "Cache-Control": "no-cache",
      },
    })
    .catch((e) => {
      console.log(
        "Error occurred retrieving patient questionnaire responses ",
        e
      );
    });
  const questionnaireResponses =
    questionnaireResponsesResult && questionnaireResponsesResult.entry
      ? questionnaireResponsesResult.entry.map((result) => result.resource)
      : null;
  return questionnaireResponses;
}

export function getEnvInstrumentList() {
  const envList = getEnv("VUE_APP_SCREENING_INSTRUMENT") || "";
  if (!envList)
    throw new Error("no instrument id(s) set in environment variable");
  console.log("instruments from environment ", envList);
  return envList.split(",").map((item) => item.trim());
}

export function getInstrumentListFromCarePlan(carePlan) {
  if (!carePlan) return null;
  let instrumentList = [];
  const activities = carePlan.activity;
  console.log("activities ", activities);
  // no activities, return empty array
  if (!activities.length) return [];

  // loop through activities that contains instantiatesCanonical
  activities.forEach((a) => {
    let qId = null;
    const detailElement = a.detail;
    // get questionnaire id for associated with this activity
    if (
      detailElement &&
      detailElement.instantiatesCanonical &&
      detailElement.instantiatesCanonical.length
    ) {
      // instantiatesCanonical is in the form of Questionnaire/[questionnaire id]
      qId = a.detail.instantiatesCanonical[0].split("/")[1];
    }
    if (!qId) return true;
    if (instrumentList.indexOf(qId) === -1) instrumentList.push(qId);

  });

  console.log(
    "Screening instrument specified in careplan ",
    instrumentList.join(", ")
  );
  return instrumentList;
}

export async function getInstrumentList(client, patientId, carePlan) {
  // if no patient id provided, get the questionnaire(s) fron the environment variable
  if (!patientId) return getEnvInstrumentList();

  // client session key
  const key = client.getState().key;

  // if we don't find a specified questionnaire from a patient's careplan,
  // we look to see if it is specifed in the sessionStorage or environment variable
  if (!carePlan) {
    // if questionnaire list is already stored within a session variable, returns it
    const sessionList = getSessionInstrumentList(key);
    if (sessionList) return sessionList;
    return getEnvInstrumentList();
  }
  // get instruments from care plan if possible
  // NOTE: this is looking to the care plan as the source of truth about what questionnaire(s) are required for the patient
  let instrumentList = carePlan
    ? getInstrumentListFromCarePlan(
        carePlan
        //await getQuestionnaireResponsesForPatient(client, patientId)
      )
    : [];

  const administeredQList = getSessionAdministeredInstrumentList(key);
  if (administeredQList) {
    let ListToAdminister = [];
    instrumentList.forEach((q) => {
      if (administeredQList.indexOf(q) === -1) ListToAdminister.push(q);
    });
    return ListToAdminister;
  }
  
  return instrumentList;
}

export function getAdministeredQuestionnaireListStorageKey(sessionKey) {
  return `administered_questionnaires_${sessionKey}`;
}

export function setSessionAdministeredInstrumentList(key, list) {
  let administeredList = [];
  const storageKey = getAdministeredQuestionnaireListStorageKey(key);
  const storedItem = sessionStorage.getItem(storageKey);
  if (storedItem) {
    administeredList = JSON.parse(storedItem);
    administeredList = [...administeredList, ...list];
  } else administeredList = list;
  sessionStorage.setItem(storageKey, JSON.stringify(administeredList));
}

export function getSessionAdministeredInstrumentList(key) {
  const storedItem = sessionStorage.getItem(
    getAdministeredQuestionnaireListStorageKey(key)
  );
  if (storedItem) return JSON.parse(storedItem);
  return null;
}

export function setSessionInstrumentList(key, data) {
  sessionStorage.setItem(`${key}_qList`, JSON.stringify(data));
}
export function getSessionInstrumentList(key) {
  const storedItem = sessionStorage.getItem(`${key}_qList`);
  if (!storedItem) return false;
  return JSON.parse(storedItem);
}
export function removeSessionInstrumentList(key) {
  sessionStorage.removeItem(`${key}_qList`);
}

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument(client, patientId, callback) {
  if (!client) throw new Error("invalid FHIR client provided");
  callback = callback || function () {};

  // perform apply to plan definition
  let carePlan = await applyDefinition(client, patientId).catch((e) => {
    // need to let the callee know about error when performing apply here
    callback({
      notificationText: `Error occurred appying plan definition: ${getErrorText(
        e
      )}`,
    });
    carePlan = null;
  });

  const instrumentList = await getInstrumentList(
    client,
    patientId,
    carePlan
  ).catch((e) => {
    throw new Error(e);
  });
  if (!instrumentList || !instrumentList.length) {
    // TODO need to figure out if no questionnaire to administer is due to whether the user has completed all the survey(s)
    return [];
  }
  setSessionInstrumentList(client.getState().key, instrumentList);
  const screeningInstrument = instrumentList[0];
  if (screeningInstrument == "usaudit") {
    let questionnaireUsAudit = await import(
      "../fhir/1_Questionnaire-USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonUsAudit = await import("../cql/UsAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireUsAudit, elmJsonUsAudit, valueSetJson];
  } else if (screeningInstrument == "whoaudit") {
    let questionnaireWhoAudit = await import(
      "../fhir/1_Questionnaire-WHOAUDIT.json"
    ).then((module) => module.default);
    let elmJsonWhoAudit = await import("../cql/WhoAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireWhoAudit, elmJsonWhoAudit, valueSetJson];
  } else if (screeningInstrument == "nidaqs2usaudit") {
    let questionnaireNidaQs = await import(
      "../fhir/1_Questionnaire-NIDAQS2USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonNidaQs = await import(
      "../cql/NidaQsToUsAuditLogicLibrary.json"
    ).then((module) => module.default);
    return [questionnaireNidaQs, elmJsonNidaQs, valueSetJson];
  } else {
    const searchData = await Promise.all([
      // look up the questionnaire based on whether the id or the name attribute matches the specified instrument id?
      client.request("/Questionnaire/?_id=" + screeningInstrument),
      client.request("/Questionnaire?name:contains=" + screeningInstrument),
    ]).catch((e) => {
      throw new Error(
        `Error retrieving questionnaire from SoF host server: ${e}`
      );
    });
    let questionnaireJson;
    const qResults = searchData.filter((q) => q.entry && q.entry.length > 0);
    if (qResults.length) {
      questionnaireJson = qResults[0].entry[0].resource;
    }
    if (!questionnaireJson) {
      throw new Error(
        `No matching ${screeningInstrument || ""} questionnaire found.`
      );
    }
    let elmJson;
    let libId = questionnaireJson.name
      ? questionnaireJson.name.toUpperCase()
      : screeningInstrument.toUpperCase();
    try {
      elmJson = await import(`../cql/${libId}_LogicLibrary.json`).then(
        (module) => module.default
      );
    } catch (e) {
      // just log error to console as not every questionnaire has a corresponding ELM library
      console.log("error ", e);
      // throw new Error(
      //   "Error loading ELM library. Unsupported ELM library may have been specified " + e
      // );
    }
    return [instrumentList, questionnaireJson, elmJson, valueSetJson];
  }
}
