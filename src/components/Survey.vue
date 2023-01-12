<template>
  <div id="surveyElement">
    <v-alert color="error" v-if="error" class="ma-4 pa-4" dark>
      <div v-html="getError()" class="font-weight-bold"></div>
    </v-alert>
    <div class="survey--actions-container">
      <v-btn
        color="primary"
        class="ml-4"
        @click="handleSkippingQuestionnaire"
        :loading="reloadInProgress"
        v-if="shouldShowSkipQuestionnaireButton()"
        >Skip this Questionnaire</v-btn
      >
    </div>
    <survey v-if="!error && ready" :survey="survey" :css="getTheme()"></survey>
    <div v-if="!error && !ready" class="ma-4 pa-4">
      <v-progress-circular
        :value="100"
        indeterminate
        color="primary"
      ></v-progress-circular>
    </div>
    <v-dialog
      content-class="dialog-container"
      v-model="showDialog"
      fullscreen
      hide-overlay
      :transition="false"
    >
      <v-card :rounded="false"
        ><div v-html="dialogMessage" class="dialog-body-container"></div
      ></v-card>
    </v-dialog>
    <v-snackbar
      v-model="snackbar"
      :timeout="snackbarTimeout"
      color="deep-orange accent-4"
      vertical="vertical"
      multi-line
    >
      <h4>{{ notificationText }}</h4>
      <template v-slot:action="{ attrs }">
        <v-btn color="white" text v-bind="attrs" @click="snackbar = false">
          Close
        </v-btn>
      </template>
    </v-snackbar>
  </div>
</template>

<script>
import converter from "questionnaire-to-survey";
import { getInstrumentCSS } from "../util/css-selector.js";
import {
  getScreeningInstrument,
  setSessionInstrumentList,
  setSessionAdministeredInstrumentList,
} from "../util/screening-selector.js";
import Worker from "cql-worker/src/cql.worker.js"; // https://github.com/webpack-contrib/worker-loader
import { initialzieCqlWorker } from "cql-worker";
import {
  getCurrentISODate,
  getEnv,
  getEnvs,
  getErrorText,
  getFHIRResourcePaths,
  getResponseValue,
  setFavicon,
  removeArrayItem,
} from "../util/util.js";
import surveyOptions from "../context/surveyjs.options.js";
import themes from "../context/themes.js";
import { FunctionFactory, Model, Serializer, StylesManager } from "survey-vue";

// Define a web worker for evaluating CQL expressions
const cqlWorker = new Worker();
// Initialize the cql-worker
let [setupExecution, sendPatientBundle, evaluateExpression] =
  initialzieCqlWorker(cqlWorker);

// Define the survey component for Vue
export default {
  props: {
    client: Object,
    patient: Object,
    authError: [String, Object, Error],
  },
  watch: {
    patient(newVal, oldVal) {
      if (this.error) return;
      if (newVal || newVal !== oldVal) {
        this.patient = newVal;
        this.init();
      }
    },
    authError(newVal, oldVal) {
      if (newVal || newVal !== oldVal) {
        this.error = newVal;
        this.ready = true;
      }
    },
  },
  data() {
    return {
      projectID: getEnv("VUE_APP_PROJECT_ID"),
      dashboardURL: getEnv("VUE_APP_DASHBOARD_URL"),
      sessionKey: 0,
      currentQuestionnaireId: null,
      currentQuestionnaireList: [],
      survey: null,
      surveyOptions: {},
      patientId: 0,
      questionnaire: {},
      patientBundle: {
        resourceType: "Bundle",
        id: "survey-bundle",
        type: "collection",
        entry: [],
      },
      questionnaireResponse: {
        resourceType: "QuestionnaireResponse",
        status: "in-progress",
        item: [],
        authored: getCurrentISODate(),
      },
      ready: false,
      error: false,
      showDialog: false,
      dialogMessage: "Saving in progress ...",
      allowSkip:
        String(getEnv("VUE_APP_ALLOW_SKIPPING_QUESTIONNAIRE")) === "true",
      reloadInProgress: false,
      snackbar: false,
      snackbarTimeout: 5000,
      notificationText: "",
    };
  },
  methods: {
    init() {
      if (this.error || !this.patient) false;
      //console.log("state ", this.client.getState("tokenResponse.id_token"));
      console.log("client state ", this.client.getState());
      this.sessionKey = this.client.getState().key;
      console.log("environment variables ", getEnvs());
      this.patientId = this.patient.id;
      this.patientBundle.entry.unshift({ resource: this.patient });
      this.initializeInstrument()
        .then(() => {
          if (this.error) return; // error getting instrument, abort
          if (this.questionnaire) {
            getInstrumentCSS(this.questionnaire.name).catch((e) =>
              console.log(`loading instrument css error: ${e}`)
            );
          }
          // set response identifier
          this.setUniqueQuestionnaireResponseIdentifier();
          this.setAppFavicon();
          // set document title to questionnaire title
          this.setDocumentTitle();
          this.initializeSurveyObj();
          this.initializeSurveyObjEvents();
          this.setQuestionnaireSubject();
          this.setQuestionnaireAuthor();
          setTimeout(() => this.setFirstInputFocus(), 500);

          // Add both the Questionnaire and QuestionnaireResponses to the patient bundle.
          // Note: Objects are pushed onto the array by reference (no copy), so we don't
          //       need to do anything fancy when we update questionnaireResponse later on.
          this.patientBundle.entry.push({ resource: this.questionnaire });
          this.patientBundle.entry.push({
            resource: this.questionnaireResponse,
          });
          // Send the patient bundle to the CQL web worker WITH FHIR resources
          sendPatientBundle(this.patientBundle);
          // by this point we already have all the FHIR resources we need, e.g. questionnaireResponse & questionnaires
          // no need to make this call to get FHIR resources, comment out for now
          // this.getFhirResources()
          //   .then(() => {
          //     // Send the patient bundle to the CQL web worker WITH FHIR resources
          //     sendPatientBundle(this.patientBundle);
          //   })
          //   .catch((e) => {
          //     console.log("Error retrieving FHIR resources ", e);
          //     // Send the patient bundle to the CQL web worker WITHOUT FHIR resources
          //     sendPatientBundle(this.patientBundle);
          //   });
          this.done();
          this.ready = true; // We don't show this component until `ready=true`
        })
        .catch((e) => {
          this.error = e;
          console.log("Error loading Questionnaire ", e);
        });
    },
    isDevelopment() {
      return (
        String(getEnv("NODE_ENV")).toLowerCase() === "development" ||
        String(getEnv("VUE_APP_SYSTEM_TYPE")).toLowerCase() === "development"
      );
    },
    getTheme() {
      const projectTheme = themes[String(this.projectID).toLowerCase()];
      if (projectTheme && projectTheme.survey) return projectTheme.survey;
      return themes["default"].survey;
    },
    setDocumentTitle() {
      if (!this.questionnaire || !this.questionnaire.title) return;
      document.title = this.questionnaire.title;
    },
    setAppFavicon() {
      setFavicon(`/${this.projectID}/img/favicon.ico`);
    },
    setFirstInputFocus() {
      if (!this.surveyOptions.focusFirstQuestionAutomatic) return;
      this.handleFocusOnFirstTextField();
    },
    initializeInstrument() {
      return getScreeningInstrument(this.client, this.patientId, (o) => {
        if (o.notificationText) {
          this.notificationText = o.notificationText;
          this.snackbar = true;
        }
      })
        .then((data) => {
          // Load the Questionniare, CQL ELM JSON, and value set cache which represents the alcohol screening instrument
          const [instrumentList, questionnaire, elmJson, valueSetJson] = data;
          if (!instrumentList || !instrumentList.length) {
            this.handleEndOfQuestionnaires(
              `<h3><span class='text-warning'>No questionnaire left to adminster.</span><br/>All questionnaires completed.</h3>`
            );
            return;
          }
          this.currentQuestionnaireList = instrumentList;
          this.currentQuestionnaireId = instrumentList[0];
          if (!questionnaire) throw Error("No questionnaire set");
          this.questionnaire = questionnaire;
          // Assemble the parameters needed by the CQL
          let cqlParameters = {
            DisplayScreeningScores:
              getEnv("VUE_APP_DISPLAY_SCREENING_SCORES").toLowerCase() ===
              "true",
            QuestionnaireURL: this.getQuestionnaireURL(),
            QuestionnaireName: questionnaire.name,
          };
          // Send the cqlWorker an initial message containing the ELM JSON representation of the CQL expressions
          setupExecution(elmJson, valueSetJson, cqlParameters);
        })
        .catch((e) => {
          this.error = e;
          console.log(e);
        });
    },
    // pair questionnaire with questionnaire response with unique identifier
    setUniqueQuestionnaireResponseIdentifier() {
      if (!this.questionnaire) return;
      this.questionnaireResponse.questionnaire = `Questionnaire/${this.questionnaire.id}`;
    },
    initializeSurveyObj() {
      const vueConverter = converter(
        FunctionFactory,
        Model,
        Serializer,
        StylesManager
      );
      const parentThis = this;
      // evaluateExpression returns a Promise that evaluates to the results from running
      // the CQL `expression`. SurveyJS expects to be provided with a function which will
      // call `this.returnResult(result)` when it completes. Here we create a wrapper
      // calls `returnResult()` when the promise resolves.
      // See: https://surveyjs.io/Examples/Library/?id=questiontype-expression-async#content-js
      let wrappedExpression = function (expression) {
        let self = this;
        // For some reason SurveyJS wraps `expression` in an array
        evaluateExpression(expression[0]).then((result) => {
          if (parentThis.isDevelopment()) {
            console.log("CQL expression ", expression[0], " result ", result);
          }
          self.returnResult(result);
        });
        return false; // This value doesn't matter
      };

      //apply theme
      var defaultThemeColors = StylesManager.ThemeColors["modern"];
      Object.entries(this.getTheme()).forEach(
        (option) => (defaultThemeColors[option[0]] = option[1])
      );

      // Create our SurveyJS object from the FHIR Questionnaire
      var model = vueConverter(this.questionnaire, wrappedExpression, "modern");

      var optionsKeys = this.questionnaire.name
        ? this.questionnaire.name.toUpperCase()
        : "default";

      //SurveyJS settings
      var options = {
        ...surveyOptions["default"],
        ...(surveyOptions[optionsKeys] || {}),
        navigateToUrl: location.href,
      };

      if (this.dashboardURL) {
        options.completedHtml =
          "<h3>The screening is complete.</h3><h3>Redirecting back to the patient list...</h3>";
      }
      Object.entries(options).forEach(
        (option) => (model[option[0]] = option[1])
      );
      if (options.showClearButton) {
        const questions = model.getAllQuestions();
        questions.forEach((item) =>
          item.setPropertyValue("showClearButton", true)
        );
      }
      this.surveyOptions = options;
      this.survey = model;
    },
    async getFhirResources() {
      const requests = getFHIRResourcePaths(this.patientId).map((resource) =>
        this.client.request(resource)
      );
      //get all resources
      return Promise.allSettled(requests)
        .then((results) => {
          results.forEach((o) => {
            let result = o.value;
            if (o.status === "rejected") {
              console.log("Error retrieving FHIR resource ", o.reason);
              return true;
            }
            if (!result) return true;

            if (result.resourceType == "Bundle" && result.entry) {
              result.entry.forEach((o) => {
                if (o && o.resource)
                  this.patientBundle.entry.push({ resource: o.resource });
              });
            } else if (Array.isArray(result)) {
              result.forEach((o) => {
                if (o.resourceType)
                  this.patientBundle.entry.push({ resource: o });
              });
            } else {
              this.patientBundle.entry.push({ resource: result });
            }
          });
        })
        .catch((e) => console.log(`Error retrieving FHIR resources ${e}`));
    }, //
    getQuestionnaireURL() {
      if (!this.questionnaire) return null;
      //used to pair questionnaire with responses
      return this.questionnaire.url;
    },
    setQuestionnaireSubject() {
      // Add the `subject` element to the QuestionnaireResponse
      this.questionnaireResponse.subject = {
        reference: `Patient/${this.patientId}`,
      };
    },
    setQuestionnaireAuthor() {
      // Record who is entering and submitting the responses
      // How do we know the author here?
      let questionnaireAuthor = getEnv(
        "VUE_APP_QUESTIONNAIRE_AUTHOR"
      ).toLowerCase();
      if (questionnaireAuthor == "practitioner") {
        // Only add the `author` element if we can get the user id from the client
        if (this.client.user && this.client.user.fhirUser) {
          this.questionnaireResponse.author = {
            reference: this.client.user.fhirUser,
          };
        } else console.log("client fhirUser not set");
      } else if (questionnaireAuthor == "patient") {
        this.questionnaireResponse.author = {
          reference: this.questionnaireResponse.subject.reference,
        };
      }
    },
    getSurveyQuestionValidator() {
      if (!this.surveyOptions || !this.surveyOptions.questionValidator)
        return function () {};
      return this.surveyOptions.questionValidator;
    },
    initializeSurveyObjEvents() {
      //add validation to question
      this.survey.onValidateQuestion.add(this.getSurveyQuestionValidator());

      this.survey.onCurrentPageChanged.add(
        function (sender) {
          this.handleOnCurrentPageChanged(sender);
        }.bind(this)
      ),
        // Add an event listener which updates questionnaireResponse based upon user responses
        this.survey.onValueChanging.add(
          function (sender, options) {
            this.handleOnValueChanging(sender, options);
          }.bind(this)
        );
      // Add a handler which will fire when the Questionnaire is submittedc
      this.survey.onComplete.add(
        function (sender, options) {
          this.handleOnComplete(sender, options);
        }.bind(this)
      );
    },
    handleFocusOnFirstTextField() {
      // find all question elements
      const questionElements = document.querySelectorAll(".sv-question");
      if (!questionElements.length) {
        return;
      }
      for (let index = 0; index < questionElements.length; index++) {
        const qElement = questionElements[index];
        // check if the question contains input field
        const inputElement = qElement ? qElement.querySelector("input") : null;
        if (inputElement) {
          const inputType = inputElement.getAttribute("type");
          // if a text input element, focus on it
          if (inputType === "text") {
            inputElement.focus();
          }
          // an input has been found so break out of the loop
          if (inputType !== "hidden") break;
        }
      }
    },
    handleOnCurrentPageChanged(sender) {
      console.log("sender page number on page changed ", sender.currentPageNo);
      // only allow skip questionnaire botón on the first page
      this.allowSkip = !sender.currentPageNo;
      setTimeout(() => {
        this.handleFocusOnFirstTextField();
      }, 300);
    },
    handleOnValueChanging(sender, options) {
      // We don't want to modify anything if the survey has been submitted/completed.
      if (sender.isCompleted == true) return;

      // Find the index of this item (may not exist)
      // NOTE: THIS WON'T WORK WITH QUESTIONNAIRES THAT HAVE NESTED ITEMS
      let answerItemIndex = this.questionnaireResponse.item.findIndex(
        (itm) => itm.linkId == options.name
      );

      if (options.value !== null) {
        let responseValue = getResponseValue(
          this.questionnaire,
          options.name,
          options.value
        );

        let question = this.questionnaire.item.filter(
          (item) => item.linkId === options.name
        )[0];
        let questionText = question && question.text ? question.text : "";

        // If the index is undefined, add a new entry to questionnaireResponse.item
        if (answerItemIndex == -1) {
          this.questionnaireResponse.item.push({
            linkId: options.name,
            text: questionText,
            answer: [
              {
                [responseValue.type]: responseValue.value,
              },
            ],
          });
        } else {
          // Otherwise update the existing index with the new response
          this.questionnaireResponse.item[answerItemIndex] = {
            linkId: options.name,
            text: questionText,
            answer: [
              {
                [responseValue.type]: responseValue.value,
              },
            ],
          };
        }
      } // end check if value is null
      else {
        // if answer item is null, e.g. due to user hitting clear button
        // remove it from questionnaire responses
        if (answerItemIndex !== -1) {
          const items = this.questionnaireResponse.item;
          items.splice(answerItemIndex, 1);
          this.questionnaireResponse.item = items;
        }
      }

      // Need to reload the patient bundle since the responses have been updated
      cqlWorker.postMessage({ patientBundle: this.patientBundle });
    },
    handleOnComplete(sender, options) {
      console.log("sender object on complete: ", sender);

      // Mark the QuestionnaireResponse as completed
      this.questionnaireResponse.status = "completed";

      // Write back to EHR only if `VUE_APP_WRITE_BACK_MODE` is set to 'smart'
      if (getEnv("VUE_APP_WRITE_BACK_MODE").toLowerCase() == "smart") {
        options.showDataSaving();
        this.showDialog = true;
        this.client
          .create(this.questionnaireResponse, {
            headers: {
              "Content-Type": "application/fhir+json",
            },
          })
          .then(() => {
            this.handleAdvanceQuestionnaireList();
            this.showDialog = true;
            this.dialogMessage = `Processing data.  Please wait...`;
            setTimeout(() => {
              options.showDataSavingSuccess();
              options.showDataSavingClear();
            }, 500);
          })
          .catch((e) => {
            this.error = `Error saving the questionnaire response for ${this.currentQuestionnaireId.toUpperCase()}.  See console for details.`;
            this.showDialog = false;
            console.log(e);
          });
      } else this.handleAdvanceQuestionnaireList();
      if (this.isDevelopment()) {
        console.log(
          "questionnaire responses ",
          JSON.stringify(this.questionnaireResponse, null, 2)
        );
      }
    },
    handleEndOfQuestionnaires(message) {
      // don't end survey session if there is still questionnaire to do
      if (this.currentQuestionnaireList.length > 0) return;

      // turn off skip flag
      this.allowSkip = false;

      // if no dashboard URL is specified, just show a message informing user that all questionnaires are completed
      this.dialogMessage = message
        ? message
        : "<h3>All questionnaire(s) are completed. You may now close the window.</h3>";
      this.showDialog = true;

      if (this.dashboardURL) {
        setTimeout(
          () => (window.location = this.dashboardURL + "/clear_session"),
          1500
        );
        return;
      }
    },
    handleSkippingQuestionnaire() {
      this.reloadInProgress = true;

      // advance to the next questionnaire if possible
      this.handleAdvanceQuestionnaireList();

      // reload page for re-processing of questionnaires to administer
      setTimeout(() => location.reload(), 500);
    },
    handleAdvanceQuestionnaireList() {
      setSessionAdministeredInstrumentList(this.sessionKey, [
        this.currentQuestionnaireId,
      ]);
      setSessionInstrumentList(
        this.sessionKey,
        removeArrayItem(
          this.currentQuestionnaireList,
          this.currentQuestionnaireId
        )
      );
    },
    shouldShowSkipQuestionnaireButton() {
      return !this.error && this.ready && this.allowSkip;
    },
    getError() {
      return getErrorText(this.error);
    },
    done() {
      this.$emit("finished", {
        title: this.questionnaire.title,
      });
    },
  },
};
</script>
