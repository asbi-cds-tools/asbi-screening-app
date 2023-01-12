import Worker from "cql-worker/src/cql.worker.js"; // https://github.com/webpack-contrib/worker-loader
import { initialzieCqlWorker } from "cql-worker";
import valueSetJson from "../cql/valueset-db.json";
import {
  getPatientCarePlan,
  getQuestionnaireResponsesForPatient,
} from "./screening-selector";
import { clearSessionStorageByKeyword, getEnv } from "./util";

function getAuthStateKey(client) {
  if (!client) return null;
  return client.getState().key;
}

async function fetchStaticFhirResources(client, patientId) {
  // client auth session key
  const key = getAuthStateKey(client);
  const prefix = "fhir_resources";
  const storageKey = `${prefix}_${key}`;
  // get resources from storage cache if possible
  if (sessionStorage.getItem(storageKey))
    return JSON.parse(sessionStorage.getItem(storageKey));

  // default FHIR resources, won't change during the current auth session
  const requests = [
    { url: "Patient/" + patientId },
    { url: "Questionnaire" },
    { url: "Condition?patient=" + patientId },
  ].map((item) => {
    return client.request({
      ...item,
      pageLimit: 0,
    });
  });
  return Promise.all(requests)
    .then((results) => {
      if (results) {
        try {
          clearSessionStorageByKeyword(prefix);
          sessionStorage.setItem(storageKey, JSON.stringify(results));
        } catch (e) {
          console.log("Error saving FHIR results to session Storage ", e);
        }
      }
      return results;
    })
    .catch((e) => {
      throw new Error(e);
    });
}

async function getQuestionnaireLogicLibrary(projectID) {
  const prefix = "CirgLibraryQuestionnaireLogic";
  const libraryName = `${prefix}_${projectID}`;
  // get it from session storage if there
  if (sessionStorage.getItem(libraryName))
    return JSON.parse(sessionStorage.getItem(libraryName));
  //get corresponding CQL logic library
  const QuestionnaireLogicLibraryJson = await import(
    `../cql/${libraryName}.json`
  )
    .then((module) => module.default)
    .catch((e) => {
      throw new Error(e);
    });
  if (QuestionnaireLogicLibraryJson) {
    try {
      clearSessionStorageByKeyword(prefix);
      sessionStorage.setItem(
        libraryName,
        JSON.stringify(QuestionnaireLogicLibraryJson)
      );
    } catch (e) {
      console.log("Error saving CQL library json to session storage ", e);
    }
  }
  return QuestionnaireLogicLibraryJson;
}

async function getPlanDefinition(client, projectID) {
  const definitionName = `CIRG-PlanDefinition-${projectID}`;
  if (sessionStorage.getItem(definitionName))
    return JSON.parse(sessionStorage.getItem(definitionName));
  //get plan definition json
  // id = CIRG-PlanDefinition-{projectId}
  const planDef = await client
    .request(`/PlanDefinition/${definitionName}`)
    .catch((e) => {
      throw new Error(e);
    });
  if (planDef) {
    try {
      sessionStorage.setItem(definitionName, JSON.stringify(planDef));
    } catch (e) {
      console.log("Error saving plan definition to session storage ", e);
    }
  }
  return planDef;
}

function getResultInBundle(results) {
  if (!results) return [];
  let bundle = [];
  // add FHIR resources results bundle
  results.forEach((result) => {
    if (result.resourceType == "Bundle" && result.entry) {
      result.entry.forEach((o) => {
        if (o && o.resource) bundle.push({ resource: o.resource });
      });
    } else if (Array.isArray(result)) {
      result.forEach((o) => {
        if (o.resourceType == "Bundle" && o.entry) {
          o.entry.forEach((item) => {
            if (item && item.resource) {
              bundle.push({ resource: item.resource });
            }
          });
        } else bundle.push({ resource: o });
      });
    } else {
      if (result) bundle.push({ resource: result });
    }
  });
  return bundle;
}

// evaluate CQL expression(s) specified in plan actions
async function getEvaluationsFromPlanActions(actions, evaluateExpressionFunc) {
  const evaluations = [];
  if (!actions || !Array.isArray(actions)) return evaluations;
  if (typeof evaluateExpressionFunc !== "function")
    throw new Error(
      "An function must be provided to evaluate CQL expression(s)."
    );
  actions.forEach((action) => {
    if (!Array.isArray(action.condition)) return;
    action.condition.forEach((item) => {
      if (
        item.kind === "applicability" &&
        item.expression &&
        item.expression.language === "text/cql"
      ) {
        let evalResult = null;
        try {
          evalResult = evaluateExpressionFunc(item.expression.expression);
        } catch (e) {
          throw new Error(
            `Error evaluating ${item.expression.expression}: ${e}`
          );
        }
        if (evalResult) {
          evaluations.push(evalResult);
        }
      }
    });
  });
  return Promise.all(evaluations).catch((e) => {
    throw new Error(e);
  });
}

// generate activities from evaluated CQL results
// e.g. { id: 'PHQ9', schedule: {repeat: {frequency: 1, period: 1, periodUnit: "d"}}
function getActivitiesFromEvalResults(evalResults) {
  let activities = [];
  if (!evalResults) return activities;
  const defaultSchedule = {
    repeat: {
      frequency: 1,
      period: 1,
      periodUnit: "d",
    },
  };
  evalResults.forEach((result) => {
    //if (!result) return true;
    activities.push({
      detail: {
        instantiatesCanonical: ["Questionnaire/" + result.questionnaireId],
        status: result.status ? result.status : "scheduled",
        scheduledTiming: result.scheduledTiming
          ? result.scheduledTiming
          : defaultSchedule,
      },
    });
  });
  return activities;
}

export const applyDefinition = async (client, patientId) => {
  // Define a web worker for evaluating CQL expressions
  const cqlWorker = new Worker();
  cqlWorker.onerror = (error) => {
    console.log("CQL worker error ", error);
    throw new Error(
      "Error occurred associated with CQL web worker.  See console for detail."
    );
  };
  // Initialize the cql-worker
  let [setupExecution, sendPatientBundle, evaluateExpression] =
    initialzieCqlWorker(cqlWorker);

  let patientBundle = {
    resourceType: "Bundle",
    id: "survey-bundle",
    type: "collection",
    entry: [],
  };

  const carePlanStub = {
    resourceType: "CarePlan",
    status: "active",
    intent: "order",
    category: [
      {
        coding: [
          {
            system: "http://snomed.info/sct",
            code: "719091000000102",
            display: "Questionnaire",
          },
        ],
        text: "Questionnaire",
      },
    ],
  };

  const projectID = getEnv("VUE_APP_PROJECT_ID");

  if (!projectID)
    throw new Error(
      "A valid project ID must be supplied for a plan definition."
    );

  // get questionnaire logic library
  const QuestionnaireLogicLibrary = await getQuestionnaireLogicLibrary(
    projectID
  ).catch((e) => {
    console.log("Project ELM logic library error ", e);
    throw new Error(
      "Error retrieving project ELM logic library. See console for detail"
    );
  });

  // get plan definition json
  const planDef = await getPlanDefinition(client, projectID).catch((e) => {
    console.log("Plan definition error ", e);
    throw new Error("Plan definition error.  See console for detail.");
  });

  if (!planDef) throw new Error("Unable to get plan definition");

  // fetch default FHIR resources, will retrieve cached results if possible
  const results = await fetchStaticFhirResources(client, patientId).catch(
    (e) => {
      console.log("Error retrieving FHIR resources ", e);
      throw new Error(
        "Error retrieving Fhir resources. See console for detail."
      );
    }
  );
  console.log("FHIR resources ", results);

  // add FHIR resources to patient bundle
  patientBundle.entry = [...patientBundle.entry, ...getResultInBundle(results)];

  // fetch questionnaire responses, NO cache here, as we want fresh responses
  const questionnaireResponses = await getQuestionnaireResponsesForPatient(
    client,
    patientId
  ).catch((e) => {
    console.log("Error retrieving questionnaire response ", e);
    throw new Error(
      "Error retrieving questionnaire response.  See console for detail."
    );
  });

  console.log("questionnaire responses ", questionnaireResponses);

  // add questionnaire responses to patient bundle
  patientBundle.entry = [
    ...patientBundle.entry,
    ...getResultInBundle(questionnaireResponses),
  ];

  console.log("patient bundle ", patientBundle);

  // Send the cqlWorker an initial message containing the ELM JSON representation of the CQL expressions
  setupExecution(QuestionnaireLogicLibrary, valueSetJson, {}); //empty CQL parameters for now
  try {
    sendPatientBundle(patientBundle);
  } catch (e) {
    throw new Error(e);
  }

  // debug
  //const debugResult = await evaluateExpression("CIRG_GDS_Responses_Today");
  //console.log("debug result - gds today ", debugResult);

  let evalResults = await getEvaluationsFromPlanActions(
    planDef.action,
    evaluateExpression
  ).catch((e) => {
    console.log("Error evaluating CQL expression ", e);
    throw Error("Error evaluating CQL expression. See console for detail");
  });
  console.log("CQL evaluation results ", evalResults);

  // filter out null results
  evalResults = evalResults.filter((result) => result);
  console.log("evaluated results ", evalResults);

  // initialize carePlan
  let carePlan;
  let patientCarePlan = await getPatientCarePlan(client, patientId);
  const hasPatientCarePlan =
    patientCarePlan && patientCarePlan.entry && patientCarePlan.entry.length;
  if (hasPatientCarePlan) carePlan = patientCarePlan.entry[0].resource;
  if (!carePlan) {
    carePlan = carePlanStub;
  }
  carePlan.subject = {
    reference: "Patient/" + patientId,
  };

  // create activities from evaluated results
  const activities = getActivitiesFromEvalResults(evalResults);
  console.log("activities ", activities);
  // update care plan activities
  carePlan.activity = activities;

  console.log("generated carePlan: ", carePlan);
  const requestParams = {
    headers: {
      "Content-Type": "application/fhir+json",
    },
  };

  // if (hasPatientCarePlan) {
  //   carePlan.replace = {
  //     reference: `CarePlan/${carePlan.id}`
  //   };
  // }
  // client.create(carePlan, requestParams);

  // // save carePlan to FHIR server
  if (hasPatientCarePlan) client.update(carePlan, requestParams);
  else client.create(carePlan, requestParams);

  return carePlan;
};

export default applyDefinition;
