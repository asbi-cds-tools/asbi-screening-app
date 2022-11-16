import valueSetJson from "../cql/valueset-db.json";
import { getEnv } from "./util.js";

export function getEnvInstrumentList() {
  const envList = getEnv("VUE_APP_SCREENING_INSTRUMENT") || "";
  console.log("instruments from environment ", envList);
  return envList.split(",").map(item => item.trim());
}

export function getInstrumentListFromCarePlan(carePlan) {
  // no care plan entry, return empty array
  if (!carePlan || !carePlan.entry || !carePlan.entry.length) return [];
  const resources = carePlan.entry;
  let instrumentList = [];
  let activities = [];
  // gather activities from careplan(s)
  resources.forEach((item) => {
    if (item.resource.activity) {
      activities = [...activities, ...item.resource.activity];
    }
  });
  // no activities, return empty array
  if (!activities.length) return [];

  // loop through activities that contains instantiatesCanonical
  activities.forEach((a) => {
    if (
      a.detail &&
      a.detail.instantiatesCanonical &&
      a.detail.instantiatesCanonical.length
    ) {
      // instantiatesCanonical is in the form of Questionnaire/[questionnaire id]
      const qId = a.detail.instantiatesCanonical[0].split("/")[1];
      // 
      if (qId && instrumentList.indexOf(qId) === -1) instrumentList.push(qId);
    }
  });
  console.log(
    "Screening instrument specified in careplan ",
    instrumentList.join(", ")
  );
  return instrumentList;
}

export async function getInstrumentList(client, patientId) {
  // if no patient id provided, get the questionnaire(s) fron the environment variable
  if (!patientId) return getEnvInstrumentList();
  const key = client.getState().key;
  // if questionnaire list is already stored within a session variable, returns it
  const sessionList = getSessionInstrumentList(key);
  if (sessionList) return sessionList;
  // get questionnaire(s) from care plan
  // NOTE: this is looking to the care plan as the source of truth about what questionnaire(s) are required for the patient
  const carePlan = await client.request(
    `CarePlan?subject=Patient/${patientId}&_sort=-_lastUpdated`
  );
  let instrumentList = getInstrumentListFromCarePlan(carePlan);
  // if we don't find a specified questionnaire from a patient's careplan,
  // we look to see if it is specifed in the environment variable
  if (!instrumentList || !instrumentList.length) {
    instrumentList = getEnvInstrumentList();
  }
  return instrumentList;
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
export async function getScreeningInstrument(client, patientId) {
  if (!client) throw new Error("invalid FHIR client provided");
  const instrumentList = await getInstrumentList(client, patientId).catch((e) =>
    console.log("Error getting instrument list ", e)
  );
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
    return [
      instrumentList,
      questionnaireJson,
      elmJson,
      valueSetJson,
    ];
  }
}
