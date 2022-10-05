import valueSetJson from "../cql/valueset-db.json";
import { getEnv } from "./util.js";

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument(client, patientId) {
  if (!client) throw new Error("invalid FHIR client provided");
  let screeningInstrument = "";
  if (patientId) {
    const carePlan = await client.request(
      `CarePlan?subject=Patient/${patientId}&_sort=-_lastUpdated`
    );
    if (carePlan && carePlan.entry && carePlan.entry.length) {
      const resources = carePlan.entry;
      // TODO: need to figure out which one is the next questionnaire to do
      // For now, assumming the first one in the activity array is the next questionnaire to do?
      if (resources.length) {
        let activities = [];
        // gather activities from careplan(s)
        resources.forEach((item) => {
          if (item.resource.activity) {
            activities = [...activities, ...item.resource.activity];
          }
        });
        // loop through activities that contains instantiatesCanonical
        if (activities.length) {
          let qList = [];
          activities.forEach((a) => {
            if (
              a.detail &&
              a.detail.instantiatesCanonical &&
              a.detail.instantiatesCanonical.length
            ) {
                // instantiatesCanonical is in the form of Questionnaire/[questionnaire id]
                const qId = a.detail.instantiatesCanonical[0].split("/")[1];
                if (qId && qList.indexOf(qId) === -1) qList.push(qId);
              }
          });
          //get the first questionnaire from the list, if any
          if (qList.length) {
            screeningInstrument = qList[0];
          }
          console.log(
            "Screening instrument specified in careplan ",
            screeningInstrument
          );
        }
      }
    }
  }
  // if we don't find a specified questionnaire from a patient's careplan,
  // we look to see if it is specifed in the environment variable
  if (!screeningInstrument)
    screeningInstrument = getEnv("VUE_APP_SCREENING_INSTRUMENT");
  if (!screeningInstrument) {
    throw new Error("No screening instrument specified.");
  }
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
    let libId = screeningInstrument.toUpperCase();
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
      // load from file and post it
      const fileJson = await import(
        `../fhir/1_Questionnaire-${screeningInstrument.toUpperCase()}.json`
      )
        .then((module) => module.default)
        .catch((e) =>
          console.log(
            "Error retrieving matching questionnaire JSON from filesystem ",
            e
          )
        );
      if (fileJson) {
        questionnaireJson = await client
          .create(fileJson, {
            headers: {
              "Content-Type": "application/fhir+json",
            },
          })
          .catch((e) => console.log("Error storing questionnaire ", e));
      }
    }
    if (!questionnaireJson) {
      throw new Error(
        `No matching ${
          screeningInstrument || ""
        } questionnaire found.`
      );
    }
    let elmJson;
    try {
      elmJson = await import(`../cql/${libId}_LogicLibrary.json`).then(
        (module) => module.default
      );
    } catch (e) {
      console.log("error ", e);
      throw new Error(
        "Error loading ELM library. Unsupported ELM library may have been specified " +
          e
      );
    }
    return [questionnaireJson, elmJson, valueSetJson];
  }
}
