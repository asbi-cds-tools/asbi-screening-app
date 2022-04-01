<template>
  <div id="surveyElement" class="ma-4">
    <survey v-if="ready" :survey="survey"></survey>
    <div v-if="ready" id="surveyResult"></div>
    <v-progress-circular :value="100" v-if="!error && !ready" indeterminate
      color="primary"></v-progress-circular>
    <v-alert color="error" v-if="error" dark>
      Error loading the application. See console for detail.
      <div v-html="error"></div>
    </v-alert>
  </div>
</template>

<script>

import converter from 'questionnaire-to-survey';
import { getScreeningInstrument } from '../util/screening-selector.js';
import Worker from "../../node_modules/cql-worker/src/cql.worker.js"; //https://github.com/webpack-contrib/worker-loader
import { initialzieCqlWorker } from 'cql-worker';
import FHIR from 'fhirclient';
import {getCurrentISODate, getObservationCategories, getResponseValue} from '../util/util.js';
import 'survey-vue/modern.css';
import "../style/app.scss";
import { FunctionFactory, Model, Serializer, StylesManager } from 'survey-vue';

// Top level definition of our FHIR client
var client;

// Define a web worker for evaluating CQL expressions
const cqlWorker = new Worker();

// Initialize the cql-worker
let [setupExecution, sendPatientBundle, evaluateExpression] = initialzieCqlWorker(cqlWorker);

// Define the survey component for Vue
export default {
  data() {
    return {
      survey: null,
      patientId: 0,
      questionnaire: {},
      patientBundle: {
        resourceType: 'Bundle',
        id: 'survey-bundle',
        type: 'collection',
        entry: []
      },
      questionnaireResponse: {
        resourceType: 'QuestionnaireResponse',
        status: 'in-progress',
        item: [],
        authored: getCurrentISODate()
      },
      ready: false,
      error: false
    };
  },
  mounted() {
    this.setAuthClient().then(() => {
      this.setPatientId().then(() => {
        this.initializeInstrument().then(() => {
          this.initializeSurvey();
          this.getFhirResources();
          this.setQuestionnaireSubject();
          // Send the patient bundle to the CQL web worker
          sendPatientBundle(this.patientBundle);
          // We don't show this component until `ready=true`
          this.ready = true;
        }).catch(e => {
          this.error = e;
          console.log("Questionnaire error ", e);
        })
      }).catch(e => {
        this.error = e;
        console.log("Set Patient Id error ", e);
      });
    }).catch(e => {
      console.log("Auth Error ", e);
      this.error = e;
      this.ready = true;
    });
  },
  methods: {
    initializeInstrument() {
      var self = this;
      return getScreeningInstrument().then(data => {
        // Load the Questionniare, CQL ELM JSON, and value set cache which represents the alcohol screening instrument
        const [questionnaire, elmJson, valueSetJson] = data;
        self.questionnaire = questionnaire;
        // Assemble the parameters needed by the CQL
        let cqlParameters = {
          DisplayScreeningScores: process.env.VUE_APP_DISPLAY_SCREENING_SCORES && process.env.VUE_APP_DISPLAY_SCREENING_SCORES.toLowerCase() == "true" ? true : false,
          QuestionnaireURL: this.questionnaire.url
        };
        // Send the cqlWorker an initial message containing the ELM JSON representation of the CQL expressions
        setupExecution(elmJson, valueSetJson, cqlParameters);

        // Define the QuestionnaireResponse which will contain the user responses.
        this.questionnaireResponse.questionnaire = questionnaire.url;

        // Add both the Questionnaire and QuestionnaireResponses to the patient bundle.
        // Note: Objects are pushed onto the array by reference (no copy), so we don't 
        //       need to do anything fancy when we update questionnaireResponse later on.
        this.patientBundle.entry.push({resource: this.questionnaire});
        this.patientBundle.entry.push({resource: this.questionnaireResponse});
      }).catch(e => {
        this.error = e;
        console.log(e);
      });
    },
    initializeSurvey() {
      const vueConverter = converter(FunctionFactory, Model, Serializer, StylesManager);
      // evaluateExpression returns a Promise that evaluates to the results from running 
      // the CQL `expression`. SurveyJS expects to be provided with a function which will 
      // call `this.returnResult(result)` when it completes. Here we create a wrapper 
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
      // Create our SurveyJS object from the FHIR Questionnaire
      var model = vueConverter(this.questionnaire, wrappedExpression, 'modern');
      var defaultOptions = {
        showQuestionNumbers: 'off',
        completeText: 'Submit',
        clearInvisibleValues: 'onHidden',
        requiredText: '',
        completedHtml: '<h3>The screening is complete.</h3><h3>You may now close the window.</h3>'
      };
      //SurveyJS settings
      Object.entries(defaultOptions).forEach(option => model[option[0]] = option[1]);
      this.survey = model;
      this.initSurveyEvents();
    },
    async setAuthClient() {
       // Wait for authorization
      try {
        client = await FHIR.oauth2.ready();
      } catch(e) {
        this.error = e;
        console.log("Auth error: ", e);
      }
    },
    async setPatientId() {
       // Get the Patient resource
      this.patientId = await client.patient.read().then((pt) => {
        if (pt) this.patientBundle.entry.unshift({resource: pt});
        console.log(pt);
        return pt.id;
      });
    },
    async getFhirResources() {
       // Get any Observation resources
      let observationQueryString = `/Observation?patient=${this.patientId}`;
      // Optionally request Observations using categories
      if (
        process.env.VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES &&
        process.env.VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES.toLowerCase() == 'true') {
        getObservationCategories().forEach(cat => {
          observationQueryString = observationQueryString + '&category=' + cat;
        });
      }
      const requests = [
        client.request('/Condition?patient=' +  this.patientId),
        client.request(observationQueryString),
        client.request('/Procedure?patient=' +  this.patientId),
        client.request('/QuestionnaireResponse?patient=' +  this.patientId)
      ];
      Promise.all(requests).then(results => {
        results.forEach(result => {
          if (!result) return true;
          if (result.resourceType == 'Bundle' && result.entry) {
            result.entry.forEach(o => {
              if (o && o.resource) this.patientBundle.entry.push({resource: o.resource});
            });
          } else if (Array.isArray(result)) {
            result.forEach(o => {
              if (o.resourceType) this.patientBundle.entry.push({resource: o});
            });
          } else {
            this.patientBundle.entry.push({resource: result});
          }
        });
      });
    }, //
    setQuestionnaireSubject() {
      // Add the `subject` element to the QuestionnaireResponse
      this.questionnaireResponse.subject = {
        reference: `Patient/${this.patientId}`
      };

      // Record who is entering and submitting the responses
      // How do we know the author here?
      let questionnaireAuthor = process.env.VUE_APP_QUESTIONNAIRE_AUTHOR && process.env.VUE_APP_QUESTIONNAIRE_AUTHOR.toLowerCase();
      if (questionnaireAuthor == 'practitioner') {
        // Only add the `author` element if we can get the user id from the client
        if (client.user && client.user.fhirUser) {
          this.questionnaireResponse.author = {
            reference: client.user.fhirUser
          };
        }
      } else if (questionnaireAuthor == 'patient') {
        this.questionnaireResponse.author = {
          reference: this.questionnaireResponse.subject.reference
        }
      }
    },
    initSurveyEvents() {
      // Add an event listener which updates questionnaireResponse based upon user responses
      this.survey.onValueChanging.add(function(sender, options) {
        // We don't want to modify anything if the survey has been submitted/completed.
        if (sender.isCompleted == true) return;
        
        if (options.value != null) {
          // Find the index of this item (may not exist)
          // NOTE: THIS WON'T WORK WITH QUESTIONNAIRES THAT HAVE NESTED ITEMS
          let answerItemIndex = this.questionnaireResponse.item.findIndex(itm => itm.linkId == options.name);
          let responseValue = getResponseValue(this.questionnaire, options.name, options.value);
          // If the index is undefined, add a new entry to questionnaireResponse.item
          if (answerItemIndex == -1) {
            this.questionnaireResponse.item.push({
              linkId: options.name,
              answer: [{
                [responseValue.type]: responseValue.value
              }]
            });
          } else { // Otherwise update the existing index with the new response
            this.questionnaireResponse.item[answerItemIndex] = {
              linkId: options.name,
              answer: [{
                [responseValue.type]: responseValue.value
              }]
            };
          }
        }
        // Need to reload the patient bundle since the responses have been updated
        cqlWorker.postMessage({patientBundle: this.patientBundle});
      }.bind(this));
      // Add a handler which will fire when the Questionnaire is submittedc
      this.survey.onComplete.add(function() {
        // Mark the QuestionnaireResponse as completed
        this.questionnaireResponse.status = 'completed'

        // Write back to EHR only if `VUE_APP_WRITE_BACK_MODE` is set to 'smart'
        if (process.env.VUE_APP_WRITE_BACK_MODE &&
            process.env.VUE_APP_WRITE_BACK_MODE.toLowerCase() == 'smart') {
          client.create(this.questionnaireResponse, {
            headers: {
              'Content-Type': 'application/fhir+json'
            }
          });
        }
        // TODO: REMOVE THIS DEVELOPMENT PLACEHOLDER
        // document.querySelector('#surveyResult').innerHTML = 
        //   'QuestionnaireResponse:\n' + '<pre><div style="text-align:left">' +
        //   JSON.stringify(this.questionnaireResponse, null, 2) + '</div></pre>';
      }.bind(this));
    },
  }
};
</script>
