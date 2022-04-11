<template>
  <div id="surveyElement">
    <survey v-if="ready" :survey="survey"></survey>
    <div v-if="ready" id="surveyResult"></div>
  </div>
</template>

<script>

import converter from 'questionnaire-to-survey';
import { getScreeningInstrument } from '../util/screening-selector.js';
import Worker from "../../node_modules/cql-worker/src/cql.worker.js"; // https://github.com/webpack-contrib/worker-loader
import { initialzieCqlWorker } from 'cql-worker';
import FHIR from 'fhirclient';
import {
  getCurrentISODate, 
  getObservationCategories, 
  getResponseValue,
  qrToObservation,
  observationToQr
} from '../util/util.js';
import 'survey-vue/modern.css';

import { FunctionFactory, Model, Serializer, StylesManager } from 'survey-vue';
const vueConverter = converter(FunctionFactory, Model, Serializer, StylesManager);

// Load the Questionniare, CQL ELM JSON, and value set cache which represents the alcohol screening instrument
const [questionnaire, elmJson, valueSetJson] = getScreeningInstrument();

// Top level definition of our FHIR client
var client;

// Define a web worker for evaluating CQL expressions
const cqlWorker = new Worker();

// Assemble the parameters needed by the CQL
let cqlParameters = {
  DisplayScreeningScores: process.env.VUE_APP_DISPLAY_SCREENING_SCORES.toLowerCase() == "true" ? true : false,
  QuestionnaireURL: questionnaire.url
};

// Initialize the cql-worker
let [setupExecution, sendPatientBundle, evaluateExpression] = initialzieCqlWorker(cqlWorker);

// Send the cqlWorker an initial message containing the ELM JSON representation of the CQL expressions
setupExecution(elmJson, valueSetJson, cqlParameters);

// evaluateExpression returns a Promise that evaluates to the results from running 
// the CQL `expression`. SurveyJS expects to be provided with a function which will 
// call `this.returnResult(result)` when it completes. Here we create a wrapper that 
// calls `returnResult()` when the promise resolves.
// See: https://surveyjs.io/Examples/Library/?id=questiontype-expression-async#content-js
let wrappedExpression = function(expression) {
  let self = this;
  // For some reason SurveyJS wraps `expression` in an array
  evaluateExpression(expression[0]).then(result => {
    self.returnResult(result);
  });

  return false; // This value doesn't matter
};

// Define the QuestionnaireResponse which will contain the user responses.
var questionnaireResponse = {
  resourceType: 'QuestionnaireResponse',
  questionnaire: questionnaire.url,
  status: 'in-progress',
  item: [],
  authored: getCurrentISODate()
};

// Add both the Questionnaire and QuestionnaireResponses to the patient bundle.
// Note: Objects are pushed onto the array by reference (no copy), so we don't 
//       need to do anything fancy when we update questionnaireResponse later on.
var patientBundle = {
  resourceType: 'Bundle',
  id: 'survey-bundle',
  type: 'collection',
  entry: []
};
patientBundle.entry.push({resource: questionnaire});
patientBundle.entry.push({resource: questionnaireResponse});

// Define the survey component for Vue
export default {
  data() {
    // Create our SurveyJS object from the FHIR Questionnaire
    var model = vueConverter(questionnaire, wrappedExpression, 'modern');
    
    // SurveyJS settings
    model.showQuestionNumbers = 'off';
    model.completeText = 'Submit';
    model.clearInvisibleValues = 'onHidden';
    model.requiredText = '';
    model.completedHtml = '<h3>The screening is complete.</h3><h3>You may now close the window.</h3>';
    
    // Return model, but note that we're not ready yet
    return {
      survey: model,
      ready: false
    };
  },
  created() {
    // Add an event listener which updates questionnaireResponse based upon user responses
    this.survey.onValueChanging.add(function(sender, options) {
      // We don't want to modify anything if the survey has been submitted/completed.
      if (sender.isCompleted == true) return;
      
      if (options.value != null) {
        // Find the index of this item (may not exist)
        // NOTE: THIS WON'T WORK WITH QUESTIONNAIRES THAT HAVE NESTED ITEMS
        let answerItemIndex = questionnaireResponse.item.findIndex(itm => itm.linkId == options.name);
        let responseValue = getResponseValue(questionnaire, options.name, options.value);
        // If the index is undefined, add a new entry to questionnaireResponse.item
        if (answerItemIndex == -1) {
          questionnaireResponse.item.push({
            linkId: options.name,
            answer: [{
              [responseValue.type]: responseValue.value
            }]
          });
        } else { // Otherwise update the existing index with the new response
          questionnaireResponse.item[answerItemIndex] = {
            linkId: options.name,
            answer: [{
              [responseValue.type]: responseValue.value
            }]
          };
        }
      }
      // Need to reload the patient bundle since the responses have been updated
      cqlWorker.postMessage({patientBundle: patientBundle});
    });
    // Add a handler which will fire when the Questionnaire is submitted
    this.survey.onComplete.add(function() {
      // Mark the QuestionnaireResponse as completed
      questionnaireResponse.status = 'completed'

      const resourceResponses = process.env.VUE_APP_RESPONSE_OBSERVATION.toLowerCase() == true
        ? qrToObservation(questionnaireResponse)
        : questionnaireResponse;

      // Write back to EHR only if `VUE_APP_WRITE_BACK_MODE` is set to 'smart'
      if (process.env.VUE_APP_WRITE_BACK_MODE.toLowerCase() == 'smart') {
        client.create(resourceResponses, {
          headers: {
            'Content-Type': 'application/fhir+json'
          }
        });
      }
    });
  },
  async mounted() {
    // Wait for authorization
    client = await FHIR.oauth2.ready();

    // Get the Patient resource
    let pid = await client.patient.read().then(function(pt) {
      if (pt) patientBundle.entry.unshift({resource: pt});
      console.log(pt);
      return pt.id;
    });

    // Get any Condition resources
    await client.request('/Condition?patient=' + pid).then(function(cd) {
      if (cd) {
        if (cd.resourceType == 'Bundle' && cd.entry) {
          cd.entry.forEach(c => {
            if (c.resource) patientBundle.entry.push({resource: c.resource});
          });
        } else if (Array.isArray(cd)) {
          cd.forEach(c => {
            if (c.resourceType) patientBundle.entry.push({resource: c});
          });
        } else {
          patientBundle.entry.push({resource: cd});
        }
      }
    });
    
    // Get any Observation resources
    let observationQueryString = `/Observation?patient=${pid}`;
    // Optionally request Observations using categories
    if (process.env.VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES.toLowerCase() == 'true') {
      getObservationCategories().forEach(cat => {
        observationQueryString = observationQueryString + '&category=' + cat;
      });
    }
    await client.request(observationQueryString).then(function(ob) {
      if (ob) {
        if (ob.resourceType == 'Bundle' && ob.entry) {
          ob.entry.forEach(o => {
            if (o.resource) patientBundle.entry.push({resource: observationToQr(o.resource)});
          });
        } else if (Array.isArray(ob)) {
          ob.forEach(o => {
            if (o.resourceType) patientBundle.entry.push({resource: observationToQr(o)});
          });
        } else {
          patientBundle.entry.push({resource: observationToQr(ob)});
        }
      }
    });

    // Get any Procedure resources
    await client.request('/Procedure?patient=' + pid).then(function(pr) {
      if (pr) {
        if (pr.resourceType == 'Bundle' && pr.entry) {
          pr.entry.forEach(p => {
            if (p.resource) patientBundle.entry.push({resource: p.resource});
          });
        } else if (Array.isArray(pr)) {
          pr.forEach(p => {
            if (p.resourceType) patientBundle.entry.push({resource: p});
          });
        } else {
          patientBundle.entry.push({resource: pr});
        }
      }
    });

    // Get any QuestionnaireResponse resources
    await client.request('/QuestionnaireResponse?patient=' + pid).then(function(qr) {
      if (qr) {
        if (qr.resourceType == 'Bundle' && qr.entry) {
          qr.entry.forEach(q => {
            if (q.resource) patientBundle.entry.push({resource: q.resource});
          });
        } else if (Array.isArray(qr)) {
          qr.forEach(q => {
            if (q.resourceType) patientBundle.entry.push({resource: q});
          });
        } else {
          patientBundle.entry.push({resource: qr});
        }
      }
    });

    // Add the `subject` element to the QuestionnaireResponse
    questionnaireResponse.subject = {
      reference: `Patient/${pid}`
    };

    // Record who is entering and submitting the responses
    let questionnaireAuthor = process.env.VUE_APP_QUESTIONNAIRE_AUTHOR.toLowerCase();
    if (questionnaireAuthor == 'practitioner') {
      // Only add the `author` element if we can get the user id from the client
      if (client.user.fhirUser) {
        questionnaireResponse.author = {
          reference: client.user.fhirUser
        };
      }
    } else if (questionnaireAuthor == 'patient') {
      questionnaireResponse.author = {
        reference: questionnaireResponse.subject.reference
      }
    }

    // Send the patient bundle to the CQL web worker
    sendPatientBundle(patientBundle);

    // We don't show this component until `ready=true`
    this.ready = true;
  }
};
</script>

<style>
@import '~survey-vue/modern.css';
input:focus {
  outline: 3px solid orange;
}
.sv-root-modern .sv-selectbase .sv-item__control:focus + .sv-item__decorator {
  border-color: orange;
  border-width: 3px;
}
.sv-question__content {
  display:inline-block;
  width:69%;
  margin-left:0;
  vertical-align: middle;
}
.sv-question__header {
  display:inline-block;
  width:30%;
  margin-bottom:0;
  vertical-align: middle;
}
div.sv-question > div.sv-question__content > fieldset > div.sv-item {
  display:inline-block;
  width:auto;
  margin-right:1em;
  margin-bottom:0;
}
div.sv-question > div.sv-question__content > fieldset {
  margin-bottom: 0;
  vertical-align: middle;
}
.sv-selectbase {
  display:inline-block;
}
span.sv-radio__decorator {
  display: none;
}
div.sv-item.sv-radio.sv-selectbase__item {
  border: 1px solid black;
  border-radius: 5%;
  margin: 10px;
}
label.sv-selectbase__label {
  padding: 10px 10px 10px 10px;
  margin: 0;
}
div.sv-item.sv-radio.sv-selectbase__item.sv-radio--checked {
  background: lightgrey;
  border-width: 2px;
}
.sv-root-modern .sv-selectbase .sv-item__control:focus ~ .sv-item__control-label {
  font-weight: bold;
  font-style: italic;
}
.sv-item__control-label {
  top: 1px;
}
h5.sv-title.sv-question__title.sv-question__title--answer {
  background-color: rgba(68, 70, 69, 0.2);
}
div[name="auditc-score"] > div.sv-question__content > div {
  font-size: 30px;
  color: black;
  padding-left: 25px;
}
div[name="audit-score"] > div.sv-question__content > div {
  font-size: 30px;
  color: black;
  padding-left: 25px;
}
input.sv-btn.sv-footer__complete-btn {
 float: left;
 font-size: larger;
}
</style>